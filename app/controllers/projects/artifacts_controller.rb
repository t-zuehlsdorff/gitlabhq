class Projects::ArtifactsController < Projects::ApplicationController
  include ExtractsPath
  include RendersBlob

  layout 'project'
  before_action :authorize_read_build!
  before_action :authorize_update_build!, only: [:keep]
  before_action :extract_ref_name_and_path
  before_action :validate_artifacts!
  before_action :set_path_and_entry, only: [:file, :raw]

  def download
    if artifacts_file.file_storage?
      send_file artifacts_file.path, disposition: 'attachment'
    else
      redirect_to artifacts_file.url
    end
  end

  def browse
    @path = params[:path]
    directory = @path ? "#{@path}/" : ''
    @entry = build.artifacts_metadata_entry(directory)

    render_404 unless @entry.exists?
  end

  def file
    blob = @entry.blob
    conditionally_expand_blob(blob)

    respond_to do |format|
      format.html do
        render 'file'
      end

      format.json do
        render_blob_json(blob)
      end
    end
  end

  def raw
    send_artifacts_entry(build, @entry)
  end

  def keep
    build.keep_artifacts!
    redirect_to project_job_path(project, build)
  end

  def latest_succeeded
    target_path = artifacts_action_path(@path, project, build)

    if target_path
      redirect_to(target_path)
    else
      render_404
    end
  end

  private

  def extract_ref_name_and_path
    return unless params[:ref_name_and_path]

    @ref_name, @path = extract_ref(params[:ref_name_and_path])
  end

  def validate_artifacts!
    render_404 unless build && build.artifacts?
  end

  def build
    @build ||= begin
      build = build_from_id || build_from_ref
      build&.present(current_user: current_user)
    end
  end

  def build_from_id
    project.builds.find_by(id: params[:job_id]) if params[:job_id]
  end

  def build_from_ref
    return unless @ref_name

    builds = project.latest_successful_builds_for(@ref_name)
    builds.find_by(name: params[:job])
  end

  def artifacts_file
    @artifacts_file ||= build.artifacts_file
  end

  def set_path_and_entry
    @path = params[:path]
    @entry = build.artifacts_metadata_entry(@path)

    render_404 unless @entry.exists?
  end
end
