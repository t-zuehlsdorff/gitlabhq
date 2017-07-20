class Projects::PagesDomainsController < Projects::ApplicationController
  layout 'project_settings'

  before_action :require_pages_enabled!
  before_action :authorize_update_pages!, except: [:show]
  before_action :domain, only: [:show, :destroy]

  def show
  end

  def new
    @domain = @project.pages_domains.new
  end

  def create
    @domain = @project.pages_domains.create(pages_domain_params)

    if @domain.valid?
      redirect_to project_pages_path(@project)
    else
      render 'new'
    end
  end

  def destroy
    @domain.destroy

    respond_to do |format|
      format.html do
        redirect_to project_pages_path(@project),
                    status: 302,
                    notice: 'Domain was removed'
      end
      format.js
    end
  end

  private

  def pages_domain_params
    params.require(:pages_domain).permit(
      :certificate,
      :key,
      :domain
    )
  end

  def domain
    @domain ||= @project.pages_domains.find_by(domain: params[:id].to_s)
  end
end
