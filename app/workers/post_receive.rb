class PostReceive
  include Sidekiq::Worker
  include DedicatedSidekiqQueue

  def perform(project_identifier, identifier, changes)
    project, is_wiki = parse_project_identifier(project_identifier)

    if project.nil?
      log("Triggered hook for non-existing project with identifier \"#{project_identifier}\"")
      return false
    end

    changes = Base64.decode64(changes) unless changes.include?(' ')
    # Use Sidekiq.logger so arguments can be correlated with execution
    # time and thread ID's.
    Sidekiq.logger.info "changes: #{changes.inspect}" if ENV['SIDEKIQ_LOG_ARGUMENTS']
    post_received = Gitlab::GitPostReceive.new(project, identifier, changes)

    if is_wiki
      process_wiki_changes(post_received)
    else
      process_project_changes(post_received)
    end
  end

  private

  def process_project_changes(post_received)
    changes = []
    refs = Set.new

    post_received.changes_refs do |oldrev, newrev, ref|
      @user ||= post_received.identify(newrev)

      unless @user
        log("Triggered hook for non-existing user \"#{post_received.identifier}\"")
        return false
      end

      if Gitlab::Git.tag_ref?(ref)
        GitTagPushService.new(post_received.project, @user, oldrev: oldrev, newrev: newrev, ref: ref).execute
      elsif Gitlab::Git.branch_ref?(ref)
        GitPushService.new(post_received.project, @user, oldrev: oldrev, newrev: newrev, ref: ref).execute
      end

      changes << Gitlab::DataBuilder::Repository.single_change(oldrev, newrev, ref)
      refs << ref
    end

    after_project_changes_hooks(post_received, @user, refs.to_a, changes)
  end

  def after_project_changes_hooks(post_received, user, refs, changes)
    hook_data = Gitlab::DataBuilder::Repository.update(post_received.project, user, changes, refs)
    SystemHooksService.new.execute_hooks(hook_data, :repository_update_hooks)
  end

  def process_wiki_changes(post_received)
    # Nothing defined here yet.
  end

  # To maintain backwards compatibility, we accept both gl_repository or
  # repository paths as project identifiers. Our plan is to migrate to
  # gl_repository only with the following plan:
  # 9.2: Handle both possible values. Keep Gitlab-Shell sending only repo paths
  # 9.3 (or patch release): Make GitLab Shell pass gl_repository if present
  # 9.4 (or patch release): Make GitLab Shell always pass gl_repository
  # 9.5 (or patch release): Handle only gl_repository as project identifier on this method
  def parse_project_identifier(project_identifier)
    if project_identifier.start_with?('/')
      Gitlab::RepoPath.parse(project_identifier)
    else
      Gitlab::GlRepository.parse(project_identifier)
    end
  end

  def log(message)
    Gitlab::GitLogger.error("POST-RECEIVE: #{message}")
  end
end
