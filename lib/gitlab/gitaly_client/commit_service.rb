module Gitlab
  module GitalyClient
    class CommitService
      # The ID of empty tree.
      # See http://stackoverflow.com/a/40884093/1856239 and https://github.com/git/git/blob/3ad8b5bf26362ac67c9020bf8c30eee54a84f56d/cache.h#L1011-L1012
      EMPTY_TREE_ID = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'.freeze

      def initialize(repository)
        @gitaly_repo = repository.gitaly_repository
        @repository = repository
      end

      def is_ancestor(ancestor_id, child_id)
        request = Gitaly::CommitIsAncestorRequest.new(
          repository: @gitaly_repo,
          ancestor_id: ancestor_id,
          child_id: child_id
        )

        GitalyClient.call(@repository.storage, :commit_service, :commit_is_ancestor, request).value
      end

      def diff_from_parent(commit, options = {})
        request_params = commit_diff_request_params(commit, options)
        request_params[:ignore_whitespace_change] = options.fetch(:ignore_whitespace_change, false)
        request = Gitaly::CommitDiffRequest.new(request_params)
        response = GitalyClient.call(@repository.storage, :diff_service, :commit_diff, request)
        Gitlab::Git::DiffCollection.new(GitalyClient::DiffStitcher.new(response), options)
      end

      def commit_deltas(commit)
        request = Gitaly::CommitDeltaRequest.new(commit_diff_request_params(commit))
        response = GitalyClient.call(@repository.storage, :diff_service, :commit_delta, request)
        response.flat_map do |msg|
          msg.deltas.map { |d| Gitlab::Git::Diff.new(d) }
        end
      end

      def tree_entry(ref, path, limit = nil)
        request = Gitaly::TreeEntryRequest.new(
          repository: @gitaly_repo,
          revision: ref,
          path: path.dup.force_encoding(Encoding::ASCII_8BIT),
          limit: limit.to_i
        )

        response = GitalyClient.call(@repository.storage, :commit_service, :tree_entry, request)
        entry = response.first
        return unless entry.oid.present?

        if entry.type == :BLOB
          rest_of_data = response.reduce("") { |memo, msg| memo << msg.data }
          entry.data += rest_of_data
        end

        entry
      end

      def commit_count(ref)
        request = Gitaly::CountCommitsRequest.new(
          repository: @gitaly_repo,
          revision: ref
        )

        GitalyClient.call(@repository.storage, :commit_service, :count_commits, request).count
      end

      def between(from, to)
        request = Gitaly::CommitsBetweenRequest.new(
          repository: @gitaly_repo,
          from: from,
          to: to
        )

        response = GitalyClient.call(@repository.storage, :commit_service, :commits_between, request)
        consume_commits_response(response)
      end

      private

      def commit_diff_request_params(commit, options = {})
        parent_id = commit.parents[0]&.id || EMPTY_TREE_ID

        {
          repository: @gitaly_repo,
          left_commit_id: parent_id,
          right_commit_id: commit.id,
          paths: options.fetch(:paths, [])
        }
      end

      def consume_commits_response(response)
        response.flat_map { |r| r.commits }
      end
    end
  end
end
