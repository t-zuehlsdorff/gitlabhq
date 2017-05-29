module Issues
  class ReopenService < Issues::BaseService
    def execute(issue)
      return issue unless can?(current_user, :update_issue, issue)

      if issue.reopen
        event_service.reopen_issue(issue, current_user)
        create_note(issue)
        notification_service.reopen_issue(issue, current_user)
        execute_hooks(issue, 'reopen')
        invalidate_cache_counts(issue.assignees, issue)
      end

      issue
    end

    private

    def create_note(issue)
      SystemNoteService.change_status(issue, issue.project, current_user, issue.state, nil)
    end
  end
end
