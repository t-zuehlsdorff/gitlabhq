class Projects::HooksController < Projects::ApplicationController
  include HooksExecution

  # Authorize
  before_action :authorize_admin_project!
  before_action :hook_logs, only: :edit

  respond_to :html

  layout "project_settings"

  def create
    @hook = @project.hooks.new(hook_params)
    @hook.save

    unless @hook.valid?
      @hooks = @project.hooks.select(&:persisted?)
      flash[:alert] = @hook.errors.full_messages.join.html_safe
    end
    redirect_to namespace_project_settings_integrations_path(@project.namespace, @project)
  end

  def edit
  end

  def update
    if hook.update_attributes(hook_params)
      flash[:notice] = 'Hook was successfully updated.'
      redirect_to namespace_project_settings_integrations_path(@project.namespace, @project)
    else
      render 'edit'
    end
  end

  def test
    if !@project.empty_repo?
      status, message = TestHookService.new.execute(hook, current_user)

      set_hook_execution_notice(status, message)
    else
      flash[:alert] = 'Hook execution failed. Ensure the project has commits.'
    end

    redirect_back_or_default(default: { action: 'index' })
  end

  def destroy
    hook.destroy

    redirect_to namespace_project_settings_integrations_path(@project.namespace, @project)
  end

  private

  def hook
    @hook ||= @project.hooks.find(params[:id])
  end

  def hook_logs
    @hook_logs ||=
      Kaminari.paginate_array(hook.web_hook_logs.order(created_at: :desc)).page(params[:page])
  end

  def hook_params
    params.require(:hook).permit(
      :job_events,
      :pipeline_events,
      :enable_ssl_verification,
      :issues_events,
      :confidential_issues_events,
      :merge_requests_events,
      :note_events,
      :push_events,
      :tag_push_events,
      :token,
      :url,
      :wiki_page_events
    )
  end
end
