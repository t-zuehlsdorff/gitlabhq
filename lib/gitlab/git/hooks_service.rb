module Gitlab
  module Git
    class HooksService
      PreReceiveError = Class.new(StandardError)

      attr_accessor :oldrev, :newrev, :ref

      def execute(committer, repository, oldrev, newrev, ref)
        @repository = repository
        @gl_id      = committer.gl_id
        @oldrev     = oldrev
        @newrev     = newrev
        @ref        = ref

        %w(pre-receive update).each do |hook_name|
          status, message = run_hook(hook_name)

          unless status
            raise PreReceiveError, message
          end
        end

        yield(self).tap do
          run_hook('post-receive')
        end
      end

      private

      def run_hook(name)
        hook = Gitlab::Git::Hook.new(name, @repository)
        hook.trigger(@gl_id, oldrev, newrev, ref)
      end
    end
  end
end
