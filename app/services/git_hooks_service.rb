class GitHooksService
  PreReceiveError = Class.new(StandardError)

  attr_accessor :oldrev, :newrev, :ref

  def execute(user, project, oldrev, newrev, ref)
    @project    = project
    @user       = Gitlab::GlId.gl_id(user)
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
    hook = Gitlab::Git::Hook.new(name, @project)
    hook.trigger(@user, oldrev, newrev, ref)
  end
end
