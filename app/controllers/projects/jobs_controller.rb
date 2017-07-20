class Projects::JobsController < Projects::ApplicationController
  before_action :build, except: [:index, :cancel_all]

  before_action :authorize_read_build!,
    only: [:index, :show, :status, :raw, :trace]
  before_action :authorize_update_build!,
    except: [:index, :show, :status, :raw, :trace, :cancel_all]

  layout 'project'

  def index
    @scope = params[:scope]
    @all_builds = project.builds.relevant
    @builds = @all_builds.order('created_at DESC')
    @builds =
      case @scope
      when 'pending'
        @builds.pending.reverse_order
      when 'running'
        @builds.running.reverse_order
      when 'finished'
        @builds.finished
      else
        @builds
      end
    @builds = @builds.includes([
      { pipeline: :project },
      :project,
      :tags
    ])
    @builds = @builds.page(params[:page]).per(30)
  end

  def cancel_all
    return access_denied! unless can?(current_user, :update_build, project)

    @project.builds.running_or_pending.each do |build|
      build.cancel if can?(current_user, :update_build, build)
    end

    redirect_to project_jobs_path(project)
  end

  def show
    @builds = @project.pipelines.find_by_sha(@build.sha).builds.order('id DESC')
    @builds = @builds.where("id not in (?)", @build.id)
    @pipeline = @build.pipeline

    respond_to do |format|
      format.html
      format.json do
        Gitlab::PollingInterval.set_header(response, interval: 10_000)

        render json: BuildSerializer
          .new(project: @project, current_user: @current_user)
          .represent(@build, {}, BuildDetailsEntity)
      end
    end
  end

  def trace
    build.trace.read do |stream|
      respond_to do |format|
        format.json do
          result = {
            id: @build.id, status: @build.status, complete: @build.complete?
          }

          if stream.valid?
            stream.limit
            state = params[:state].presence
            trace = stream.html_with_state(state)
            result.merge!(trace.to_h)
          end

          render json: result
        end
      end
    end
  end

  def retry
    return respond_422 unless @build.retryable?

    build = Ci::Build.retry(@build, current_user)
    redirect_to build_path(build)
  end

  def play
    return respond_422 unless @build.playable?

    build = @build.play(current_user)
    redirect_to build_path(build)
  end

  def cancel
    return respond_422 unless @build.cancelable?

    @build.cancel
    redirect_to build_path(@build)
  end

  def status
    render json: BuildSerializer
      .new(project: @project, current_user: @current_user)
      .represent_status(@build)
  end

  def erase
    if @build.erase(erased_by: current_user)
      redirect_to project_job_path(project, @build),
                notice: "Build has been successfully erased!"
    else
      respond_422
    end
  end

  def raw
    build.trace.read do |stream|
      if stream.file?
        send_file stream.path, type: 'text/plain; charset=utf-8', disposition: 'inline'
      else
        render_404
      end
    end
  end

  private

  def authorize_update_build!
    return access_denied! unless can?(current_user, :update_build, build)
  end

  def build
    @build ||= project.builds.find(params[:id])
      .present(current_user: current_user)
  end

  def build_path(build)
    project_job_path(build.project, build)
  end
end
