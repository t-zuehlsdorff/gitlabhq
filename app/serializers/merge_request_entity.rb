class MergeRequestEntity < IssuableEntity
  include RequestAwareEntity

  expose :in_progress_merge_commit_sha
  expose :locked_at
  expose :merge_commit_sha
  expose :merge_error
  expose :merge_params
  expose :merge_status
  expose :merge_user_id
  expose :merge_when_pipeline_succeeds
  expose :source_branch
  expose :source_project_id
  expose :target_branch
  expose :target_project_id

  # Events
  expose :merge_event, using: EventEntity
  expose :closed_event, using: EventEntity

  # User entities
  expose :author, using: UserEntity
  expose :merge_user, using: UserEntity

  # Diff sha's
  expose :diff_head_sha do |merge_request|
    merge_request.diff_head_sha if merge_request.diff_head_commit
  end

  expose :merge_commit_sha
  expose :merge_commit_message
  expose :head_pipeline, with: PipelineDetailsEntity, as: :pipeline

  # Booleans
  expose :work_in_progress?, as: :work_in_progress
  expose :source_branch_exists?, as: :source_branch_exists
  expose :mergeable_discussions_state?, as: :mergeable_discussions_state
  expose :branch_missing?, as: :branch_missing
  expose :commits_count
  expose :cannot_be_merged?, as: :has_conflicts
  expose :can_be_merged?, as: :can_be_merged
  expose :remove_source_branch?, as: :remove_source_branch

  expose :project_archived do |merge_request|
    merge_request.project.archived?
  end

  expose :only_allow_merge_if_pipeline_succeeds do |merge_request|
    merge_request.project.only_allow_merge_if_pipeline_succeeds?
  end

  # CI related
  expose :has_ci?, as: :has_ci
  expose :ci_status do |merge_request|
    presenter(merge_request).ci_status
  end

  expose :issues_links do
    expose :assign_to_closing do |merge_request|
      presenter(merge_request).assign_to_closing_issues_link
    end

    expose :closing do |merge_request|
      presenter(merge_request).closing_issues_links
    end

    expose :mentioned_but_not_closing do |merge_request|
      presenter(merge_request).mentioned_issues_links
    end
  end

  expose :source_branch_with_namespace_link do |merge_request|
    presenter(merge_request).source_branch_with_namespace_link
  end

  expose :source_branch_path do |merge_request|
    presenter(merge_request).source_branch_path
  end

  expose :current_user do
    expose :can_remove_source_branch do |merge_request|
      merge_request.source_branch_exists? && merge_request.can_remove_source_branch?(current_user)
    end

    expose :can_revert_on_current_merge_request do |merge_request|
      presenter(merge_request).can_revert_on_current_merge_request?
    end

    expose :can_cherry_pick_on_current_merge_request do |merge_request|
      presenter(merge_request).can_cherry_pick_on_current_merge_request?
    end
  end

  # Paths
  #
  expose :target_branch_commits_path do |merge_request|
    presenter(merge_request).target_branch_commits_path
  end

  expose :target_branch_tree_path do |merge_request|
    presenter(merge_request).target_branch_tree_path
  end

  expose :new_blob_path do |merge_request|
    if can?(current_user, :push_code, merge_request.project)
      project_new_blob_path(merge_request.project, merge_request.source_branch)
    end
  end

  expose :conflict_resolution_path do |merge_request|
    presenter(merge_request).conflict_resolution_path
  end

  expose :remove_wip_path do |merge_request|
    presenter(merge_request).remove_wip_path
  end

  expose :cancel_merge_when_pipeline_succeeds_path do |merge_request|
    presenter(merge_request).cancel_merge_when_pipeline_succeeds_path
  end

  expose :create_issue_to_resolve_discussions_path do |merge_request|
    presenter(merge_request).create_issue_to_resolve_discussions_path
  end

  expose :merge_path do |merge_request|
    presenter(merge_request).merge_path
  end

  expose :cherry_pick_in_fork_path do |merge_request|
    presenter(merge_request).cherry_pick_in_fork_path
  end

  expose :revert_in_fork_path do |merge_request|
    presenter(merge_request).revert_in_fork_path
  end

  expose :email_patches_path do |merge_request|
    project_merge_request_path(merge_request.project, merge_request, format: :patch)
  end

  expose :plain_diff_path do |merge_request|
    project_merge_request_path(merge_request.project, merge_request, format: :diff)
  end

  expose :status_path do |merge_request|
    project_merge_request_path(merge_request.target_project, merge_request, format: :json)
  end

  expose :ci_environments_status_path do |merge_request|
    ci_environments_status_project_merge_request_path(merge_request.project, merge_request)
  end

  expose :merge_commit_message_with_description do |merge_request|
    merge_request.merge_commit_message(include_description: true)
  end

  expose :diverged_commits_count do |merge_request|
    if merge_request.open? && merge_request.diverged_from_target_branch?
      merge_request.diverged_commits_count
    else
      0
    end
  end

  expose :commit_change_content_path do |merge_request|
    commit_change_content_project_merge_request_path(merge_request.project, merge_request)
  end

  private

  delegate :current_user, to: :request

  def presenter(merge_request)
    @presenters ||= {}
    @presenters[merge_request] ||= MergeRequestPresenter.new(merge_request, current_user: current_user)
  end
end
