# Gitlab::Git::Commit is a wrapper around native Rugged::Commit object
module Gitlab
  module Git
    class Commit
      include Gitlab::EncodingHelper

      attr_accessor :raw_commit, :head

      SERIALIZE_KEYS = [
        :id, :message, :parent_ids,
        :authored_date, :author_name, :author_email,
        :committed_date, :committer_name, :committer_email
      ].freeze

      attr_accessor *SERIALIZE_KEYS # rubocop:disable Lint/AmbiguousOperator

      delegate :tree, to: :rugged_commit

      def ==(other)
        return false unless other.is_a?(Gitlab::Git::Commit)

        id && id == other.id
      end

      class << self
        # Get commits collection
        #
        # Ex.
        #   Commit.where(
        #     repo: repo,
        #     ref: 'master',
        #     path: 'app/models',
        #     limit: 10,
        #     offset: 5,
        #   )
        #
        def where(options)
          repo = options.delete(:repo)
          raise 'Gitlab::Git::Repository is required' unless repo.respond_to?(:log)

          repo.log(options)
        end

        # Get single commit
        #
        # Ex.
        #   Commit.find(repo, '29eda46b')
        #
        #   Commit.find(repo, 'master')
        #
        # Gitaly migration: https://gitlab.com/gitlab-org/gitaly/issues/321
        def find(repo, commit_id = "HEAD")
          # Already a commit?
          return commit_id if commit_id.is_a?(Gitlab::Git::Commit)

          # A rugged reference?
          commit_id = Gitlab::Git::Ref.dereference_object(commit_id)
          return decorate(repo, commit_id) if commit_id.is_a?(Rugged::Commit)

          # Some weird thing?
          return nil unless commit_id.is_a?(String)

          commit = repo.gitaly_migrate(:find_commit) do |is_enabled|
            if is_enabled
              repo.gitaly_commit_client.find_commit(commit_id)
            else
              obj = repo.rev_parse_target(commit_id)

              obj.is_a?(Rugged::Commit) ? obj : nil
            end
          end

          decorate(repo, commit) if commit
        rescue Rugged::ReferenceError, Rugged::InvalidError, Rugged::ObjectError,
               Gitlab::Git::CommandError, Gitlab::Git::Repository::NoRepository
          nil
        end

        # Get last commit for HEAD
        #
        # Ex.
        #   Commit.last(repo)
        #
        def last(repo)
          find(repo)
        end

        # Get last commit for specified path and ref
        #
        # Ex.
        #   Commit.last_for_path(repo, '29eda46b', 'app/models')
        #
        #   Commit.last_for_path(repo, 'master', 'Gemfile')
        #
        def last_for_path(repo, ref, path = nil)
          where(
            repo: repo,
            ref: ref,
            path: path,
            limit: 1
          ).first
        end

        # Get commits between two revspecs
        # See also #repository.commits_between
        #
        # Ex.
        #   Commit.between(repo, '29eda46b', 'master')
        #
        def between(repo, base, head)
          Gitlab::GitalyClient.migrate(:commits_between) do |is_enabled|
            if is_enabled
              repo.gitaly_commit_client.between(base, head)
            else
              repo.rugged_commits_between(base, head).map { |c| decorate(repo, c) }
            end
          end
        rescue Rugged::ReferenceError
          []
        end

        # Returns commits collection
        #
        # Ex.
        #   Commit.find_all(
        #     repo,
        #     ref: 'master',
        #     max_count: 10,
        #     skip: 5,
        #     order: :date
        #   )
        #
        #   +options+ is a Hash of optional arguments to git
        #     :ref is the ref from which to begin (SHA1 or name)
        #     :max_count is the maximum number of commits to fetch
        #     :skip is the number of commits to skip
        #     :order is the commits order and allowed value is :none (default), :date,
        #        :topo, or any combination of them (in an array). Commit ordering types
        #        are documented here:
        #        http://www.rubydoc.info/github/libgit2/rugged/Rugged#SORT_NONE-constant)
        #
        # Gitaly migration: https://gitlab.com/gitlab-org/gitaly/issues/326
        def find_all(repo, options = {})
          Gitlab::GitalyClient.migrate(:find_all_commits) do |is_enabled|
            if is_enabled
              find_all_by_gitaly(repo, options)
            else
              find_all_by_rugged(repo, options)
            end
          end
        end

        def find_all_by_rugged(repo, options = {})
          actual_options = options.dup

          allowed_options = [:ref, :max_count, :skip, :order]

          actual_options.keep_if do |key|
            allowed_options.include?(key)
          end

          default_options = { skip: 0 }
          actual_options = default_options.merge(actual_options)

          rugged = repo.rugged
          walker = Rugged::Walker.new(rugged)

          if actual_options[:ref]
            walker.push(rugged.rev_parse_oid(actual_options[:ref]))
          else
            rugged.references.each("refs/heads/*") do |ref|
              walker.push(ref.target_id)
            end
          end

          walker.sorting(rugged_sort_type(actual_options[:order]))

          commits = []
          offset = actual_options[:skip]
          limit = actual_options[:max_count]
          walker.each(offset: offset, limit: limit) do |commit|
            commits.push(decorate(repo, commit))
          end

          walker.reset

          commits
        rescue Rugged::OdbError
          []
        end

        def find_all_by_gitaly(repo, options = {})
          Gitlab::GitalyClient::CommitService.new(repo).find_all_commits(options)
        end

        def decorate(repository, commit, ref = nil)
          Gitlab::Git::Commit.new(repository, commit, ref)
        end

        # Returns the `Rugged` sorting type constant for one or more given
        # sort types. Valid keys are `:none`, `:topo`, and `:date`, or an array
        # containing more than one of them. `:date` uses a combination of date and
        # topological sorting to closer mimic git's native ordering.
        def rugged_sort_type(sort_type)
          @rugged_sort_types ||= {
            none: Rugged::SORT_NONE,
            topo: Rugged::SORT_TOPO,
            date: Rugged::SORT_DATE | Rugged::SORT_TOPO
          }

          @rugged_sort_types.fetch(sort_type, Rugged::SORT_NONE)
        end

        def shas_with_signatures(repository, shas)
          shas.select do |sha|
            begin
              Rugged::Commit.extract_signature(repository.rugged, sha)
            rescue Rugged::OdbError
              false
            end
          end
        end
      end

      def initialize(repository, raw_commit, head = nil)
        raise "Nil as raw commit passed" unless raw_commit

        case raw_commit
        when Hash
          init_from_hash(raw_commit)
        when Rugged::Commit
          init_from_rugged(raw_commit)
        when Gitaly::GitCommit
          init_from_gitaly(raw_commit)
        else
          raise "Invalid raw commit type: #{raw_commit.class}"
        end

        @repository = repository
        @head = head
      end

      def sha
        id
      end

      def short_id(length = 10)
        id.to_s[0..length]
      end

      def safe_message
        @safe_message ||= message
      end

      def created_at
        committed_date
      end

      # Was this commit committed by a different person than the original author?
      def different_committer?
        author_name != committer_name || author_email != committer_email
      end

      def parent_id
        parent_ids.first
      end

      # Shows the diff between the commit's parent and the commit.
      #
      # Cuts out the header and stats from #to_patch and returns only the diff.
      #
      # Gitaly migration: https://gitlab.com/gitlab-org/gitaly/issues/324
      def to_diff
        Gitlab::GitalyClient.migrate(:commit_patch) do |is_enabled|
          if is_enabled
            @repository.gitaly_commit_client.patch(id)
          else
            rugged_diff_from_parent.patch
          end
        end
      end

      # Returns a diff object for the changes from this commit's first parent.
      # If there is no parent, then the diff is between this commit and an
      # empty repo. See Repository#diff for keys allowed in the +options+
      # hash.
      def diff_from_parent(options = {})
        Gitlab::GitalyClient.migrate(:commit_raw_diffs) do |is_enabled|
          if is_enabled
            @repository.gitaly_commit_client.diff_from_parent(self, options)
          else
            rugged_diff_from_parent(options)
          end
        end
      end

      def rugged_diff_from_parent(options = {})
        options ||= {}
        break_rewrites = options[:break_rewrites]
        actual_options = Gitlab::Git::Diff.filter_diff_options(options)

        diff = if rugged_commit.parents.empty?
                 rugged_commit.diff(actual_options.merge(reverse: true))
               else
                 rugged_commit.parents[0].diff(rugged_commit, actual_options)
               end

        diff.find_similar!(break_rewrites: break_rewrites)
        diff
      end

      def deltas
        @deltas ||= begin
          deltas = Gitlab::GitalyClient.migrate(:commit_deltas) do |is_enabled|
            if is_enabled
              @repository.gitaly_commit_client.commit_deltas(self)
            else
              rugged_diff_from_parent.each_delta
            end
          end

          deltas.map { |delta| Gitlab::Git::Diff.new(delta) }
        end
      end

      def has_zero_stats?
        stats.total.zero?
      rescue
        true
      end

      def no_commit_message
        "--no commit message"
      end

      def to_hash
        serialize_keys.map.with_object({}) do |key, hash|
          hash[key] = send(key) # rubocop:disable GitlabSecurity/PublicSend
        end
      end

      def date
        committed_date
      end

      def diffs(options = {})
        Gitlab::Git::DiffCollection.new(diff_from_parent(options), options)
      end

      def parents
        parent_ids.map { |oid| self.class.find(@repository, oid) }.compact
      end

      def stats
        Gitlab::Git::CommitStats.new(self)
      end

      def to_patch(options = {})
        begin
          rugged_commit.to_mbox(options)
        rescue Rugged::InvalidError => ex
          if ex.message =~ /commit \w+ is a merge commit/i
            'Patch format is not currently supported for merge commits.'
          end
        end
      end

      # Get a collection of Rugged::Reference objects for this commit.
      #
      # Ex.
      #   commit.ref(repo)
      #
      def refs(repo)
        repo.refs_hash[id]
      end

      # Get ref names collection
      #
      # Ex.
      #   commit.ref_names(repo)
      #
      def ref_names(repo)
        refs(repo).map do |ref|
          ref.name.sub(%r{^refs/(heads|remotes|tags)/}, "")
        end
      end

      def message
        encode! @message
      end

      def author_name
        encode! @author_name
      end

      def author_email
        encode! @author_email
      end

      def committer_name
        encode! @committer_name
      end

      def committer_email
        encode! @committer_email
      end

      def rugged_commit
        @rugged_commit ||= if raw_commit.is_a?(Rugged::Commit)
                             raw_commit
                           else
                             @repository.rev_parse_target(id)
                           end
      end

      private

      def init_from_hash(hash)
        raw_commit = hash.symbolize_keys

        serialize_keys.each do |key|
          send("#{key}=", raw_commit[key]) # rubocop:disable GitlabSecurity/PublicSend
        end
      end

      def init_from_rugged(commit)
        author = commit.author
        committer = commit.committer

        @raw_commit = commit
        @id = commit.oid
        @message = commit.message
        @authored_date = author[:time]
        @committed_date = committer[:time]
        @author_name = author[:name]
        @author_email = author[:email]
        @committer_name = committer[:name]
        @committer_email = committer[:email]
        @parent_ids = commit.parents.map(&:oid)
      end

      def init_from_gitaly(commit)
        @raw_commit = commit
        @id = commit.id
        # TODO: Once gitaly "takes over" Rugged consider separating the
        # subject from the message to make it clearer when there's one
        # available but not the other.
        @message = (commit.body.presence || commit.subject).dup
        @authored_date = Time.at(commit.author.date.seconds).utc
        @author_name = commit.author.name.dup
        @author_email = commit.author.email.dup
        @committed_date = Time.at(commit.committer.date.seconds).utc
        @committer_name = commit.committer.name.dup
        @committer_email = commit.committer.email.dup
        @parent_ids = commit.parent_ids
      end

      def serialize_keys
        SERIALIZE_KEYS
      end
    end
  end
end
