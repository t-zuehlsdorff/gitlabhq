# Defines a specific location, identified by paths and line numbers,
# within a specific diff, identified by start, head and base commit ids.
module Gitlab
  module Diff
    class Position
      attr_reader :old_path
      attr_reader :new_path
      attr_reader :old_line
      attr_reader :new_line
      attr_reader :base_sha
      attr_reader :start_sha
      attr_reader :head_sha

      def initialize(attrs = {})
        if diff_file = attrs[:diff_file]
          attrs[:diff_refs] = diff_file.diff_refs
          attrs[:old_path] = diff_file.old_path
          attrs[:new_path] = diff_file.new_path
        end

        if diff_refs = attrs[:diff_refs]
          attrs[:base_sha]  = diff_refs.base_sha
          attrs[:start_sha] = diff_refs.start_sha
          attrs[:head_sha]  = diff_refs.head_sha
        end

        @old_path = attrs[:old_path]
        @new_path = attrs[:new_path]
        @base_sha  = attrs[:base_sha]
        @start_sha = attrs[:start_sha]
        @head_sha  = attrs[:head_sha]

        @old_line = attrs[:old_line]
        @new_line = attrs[:new_line]
      end

      # `Gitlab::Diff::Position` objects are stored as serialized attributes in
      # `DiffNote`, which use YAML to encode and decode objects.
      # `#init_with` and `#encode_with` can be used to customize the en/decoding
      # behavior. In this case, we override these to prevent memoized instance
      # variables like `@diff_file` and `@diff_line` from being serialized.
      def init_with(coder)
        initialize(coder['attributes'])

        self
      end

      def encode_with(coder)
        coder['attributes'] = self.to_h
      end

      def key
        @key ||= [base_sha, start_sha, head_sha, Digest::SHA1.hexdigest(old_path || ""), Digest::SHA1.hexdigest(new_path || ""), old_line, new_line]
      end

      def ==(other)
        other.is_a?(self.class) && key == other.key
      end

      def to_h
        {
          old_path: old_path,
          new_path: new_path,
          old_line: old_line,
          new_line: new_line,
          base_sha:  base_sha,
          start_sha: start_sha,
          head_sha:  head_sha
        }
      end

      def inspect
        %(#<#{self.class}:#{object_id} #{to_h}>)
      end

      def complete?
        file_path.present? &&
          (old_line || new_line) &&
          diff_refs.complete?
      end

      def to_json(opts = nil)
        JSON.generate(self.to_h, opts)
      end

      def type
        if old_line && new_line
          nil
        elsif new_line
          'new'
        else
          'old'
        end
      end

      def unchanged?
        type.nil?
      end

      def added?
        type == 'new'
      end

      def removed?
        type == 'old'
      end

      def paths
        [old_path, new_path].compact.uniq
      end

      def file_path
        new_path.presence || old_path
      end

      def diff_refs
        @diff_refs ||= DiffRefs.new(base_sha: base_sha, start_sha: start_sha, head_sha: head_sha)
      end

      def diff_file(repository)
        @diff_file ||= begin
          if RequestStore.active?
            key = {
              project_id: repository.project.id,
              start_sha: start_sha,
              head_sha: head_sha,
              path: file_path
            }

            RequestStore.fetch(key) { find_diff_file(repository) }
          else
            find_diff_file(repository)
          end
        end
      end

      def diff_line(repository)
        @diff_line ||= diff_file(repository)&.line_for_position(self)
      end

      def line_code(repository)
        @line_code ||= diff_file(repository)&.line_code_for_position(self)
      end

      private

      def find_diff_file(repository)
        return unless diff_refs.complete?

        diff_refs.compare_in(repository.project).diffs(paths: paths, expanded: true).diff_files.first
      end
    end
  end
end
