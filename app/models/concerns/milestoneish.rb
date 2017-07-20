module Milestoneish
  def closed_items_count(user)
    memoize_per_user(user, :closed_items_count) do
      (count_issues_by_state(user)['closed'] || 0) + merge_requests.closed_and_merged.size
    end
  end

  def total_items_count(user)
    memoize_per_user(user, :total_items_count) do
      total_issues_count(user) + merge_requests.size
    end
  end

  def total_issues_count(user)
    count_issues_by_state(user).values.sum
  end

  def complete?(user)
    total_items_count(user) > 0 && total_items_count(user) == closed_items_count(user)
  end

  def percent_complete(user)
    ((closed_items_count(user) * 100) / total_items_count(user)).abs
  rescue ZeroDivisionError
    0
  end

  def remaining_days
    return 0 if !due_date || expired?

    (due_date - Date.today).to_i
  end

  def elapsed_days
    return 0 if !start_date || start_date.future?

    (Date.today - start_date).to_i
  end

  def issues_visible_to_user(user)
    memoize_per_user(user, :issues_visible_to_user) do
      IssuesFinder.new(user, issues_finder_params)
        .execute.preload(:assignees).where(milestone_id: milestoneish_ids)
    end
  end

  def sorted_issues(user)
    issues_visible_to_user(user).preload_associations.sort('label_priority')
  end

  def sorted_merge_requests
    merge_requests.sort('label_priority')
  end

  def upcoming?
    start_date && start_date.future?
  end

  def expires_at
    if due_date
      if due_date.past?
        "expired on #{due_date.to_s(:medium)}"
      else
        "expires on #{due_date.to_s(:medium)}"
      end
    end
  end

  def expired?
    due_date && due_date.past?
  end

  def is_group_milestone?
    false
  end

  def is_project_milestone?
    false
  end

  def is_legacy_group_milestone?
    false
  end

  def is_dashboard_milestone?
    false
  end

  private

  def count_issues_by_state(user)
    memoize_per_user(user, :count_issues_by_state) do
      issues_visible_to_user(user).reorder(nil).group(:state).count
    end
  end

  def memoize_per_user(user, method_name)
    @memoized ||= {}
    @memoized[method_name] ||= {}
    @memoized[method_name][user&.id] ||= yield
  end

  # override in a class that includes this module to get a faster query
  # from IssuesFinder
  def issues_finder_params
    {}
  end
end
