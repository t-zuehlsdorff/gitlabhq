module IssuableCollections
  extend ActiveSupport::Concern
  include SortingHelper
  include Gitlab::IssuableMetadata

  included do
    helper_method :issues_finder
    helper_method :merge_requests_finder
  end

  private

  def issues_collection
    issues_finder.execute.preload(:project, :author, :assignees, :labels, :milestone, project: :namespace)
  end

  def merge_requests_collection
    merge_requests_finder.execute.preload(:source_project, :target_project, :author, :assignee, :labels, :milestone, :head_pipeline, target_project: :namespace, merge_request_diff: :merge_request_diff_commits)
  end

  def issues_finder
    @issues_finder ||= issuable_finder_for(IssuesFinder)
  end

  def merge_requests_finder
    @merge_requests_finder ||= issuable_finder_for(MergeRequestsFinder)
  end

  def issuable_finder_for(finder_class)
    finder_class.new(current_user, filter_params)
  end

  def filter_params
    set_sort_order_from_cookie
    set_default_state

    # Skip irrelevant Rails routing params
    @filter_params = params.dup.except(:controller, :action, :namespace_id)
    @filter_params[:sort] ||= default_sort_order

    @sort = @filter_params[:sort]

    if @project
      @filter_params[:project_id] = @project.id
    elsif @group
      @filter_params[:group_id] = @group.id
    else
      # TODO: this filter ignore issues/mr created in public or
      # internal repos where you are not a member. Enable this filter
      # or improve current implementation to filter only issues you
      # created or assigned or mentioned
      # @filter_params[:authorized_only] = true
    end

    @filter_params
  end

  def set_default_state
    params[:state] = 'opened' if params[:state].blank?
  end

  def set_sort_order_from_cookie
    key = 'issuable_sort'

    cookies[key] = params[:sort] if params[:sort].present?

    # id_desc and id_asc are old values for these two.
    cookies[key] = sort_value_recently_created if cookies[key] == 'id_desc'
    cookies[key] = sort_value_oldest_created if cookies[key] == 'id_asc'

    params[:sort] = cookies[key]
  end

  def default_sort_order
    case params[:state]
    when 'opened', 'all' then sort_value_recently_created
    when 'merged', 'closed' then sort_value_recently_updated
    else sort_value_recently_created
    end
  end
end
