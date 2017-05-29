module MergeRequests
  class UpdateService < MergeRequests::BaseService
    def execute(merge_request)
      # We don't allow change of source/target projects and source branch
      # after merge request was created
      params.except!(:source_project_id)
      params.except!(:target_project_id)
      params.except!(:source_branch)

      merge_from_slash_command(merge_request) if params[:merge]

      if merge_request.closed_without_fork?
        params.except!(:target_branch, :force_remove_source_branch)
      end

      if params[:force_remove_source_branch].present?
        merge_request.merge_params['force_remove_source_branch'] = params.delete(:force_remove_source_branch)
      end

      handle_wip_event(merge_request)
      update(merge_request)
    end

    def handle_changes(merge_request, options)
      old_labels = options[:old_labels] || []
      old_mentioned_users = options[:old_mentioned_users] || []

      if has_changes?(merge_request, old_labels: old_labels)
        todo_service.mark_pending_todos_as_done(merge_request, current_user)
      end

      if merge_request.previous_changes.include?('title') ||
          merge_request.previous_changes.include?('description')
        todo_service.update_merge_request(merge_request, current_user, old_mentioned_users)
      end

      if merge_request.previous_changes.include?('target_branch')
        create_branch_change_note(merge_request, 'target',
                                  merge_request.previous_changes['target_branch'].first,
                                  merge_request.target_branch)
      end

      if merge_request.previous_changes.include?('milestone_id')
        create_milestone_note(merge_request)
      end

      if merge_request.previous_changes.include?('assignee_id')
        create_assignee_note(merge_request)
        notification_service.reassigned_merge_request(merge_request, current_user)
        todo_service.reassigned_merge_request(merge_request, current_user)
      end

      if merge_request.previous_changes.include?('target_branch') ||
          merge_request.previous_changes.include?('source_branch')
        merge_request.mark_as_unchecked
      end

      added_labels = merge_request.labels - old_labels
      if added_labels.present?
        notification_service.relabeled_merge_request(
          merge_request,
          added_labels,
          current_user
        )
      end

      added_mentions = merge_request.mentioned_users - old_mentioned_users
      if added_mentions.present?
        notification_service.new_mentions_in_merge_request(
          merge_request,
          added_mentions,
          current_user
        )
      end
    end

    def merge_from_slash_command(merge_request)
      last_diff_sha = params.delete(:merge)
      return unless merge_request.mergeable_with_slash_command?(current_user, last_diff_sha: last_diff_sha)

      merge_request.update(merge_error: nil)

      if merge_request.head_pipeline && merge_request.head_pipeline.active?
        MergeRequests::MergeWhenPipelineSucceedsService.new(project, current_user).execute(merge_request)
      else
        MergeWorker.perform_async(merge_request.id, current_user.id, {})
      end
    end

    def reopen_service
      MergeRequests::ReopenService
    end

    def close_service
      MergeRequests::CloseService
    end

    def after_update(issuable)
      issuable.cache_merge_request_closes_issues!(current_user)
    end

    private

    def handle_wip_event(merge_request)
      if wip_event = params.delete(:wip_event)
        # We update the title that is provided in the params or we use the mr title
        title = params[:title] || merge_request.title
        params[:title] = case wip_event
                         when 'wip' then MergeRequest.wip_title(title)
                         when 'unwip' then MergeRequest.wipless_title(title)
                         end
      end
    end
  end
end
