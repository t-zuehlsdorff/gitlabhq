class Projects::GraphsController < Projects::ApplicationController
  include ExtractsPath

  # Authorize
  before_action :require_non_empty_project
  before_action :assign_ref_vars
  before_action :authorize_download_code!

  def show
    respond_to do |format|
      format.html
      format.json do
        fetch_graph
      end
    end
  end

  def commits
    redirect_to action: 'charts'
  end

  def languages
    redirect_to action: 'charts'
  end

  def charts
    get_commits
    get_languages
  end

  def ci
    redirect_to charts_namespace_project_pipelines_path(@project.namespace, @project)
  end

  private

  def get_commits
    @commits = @project.repository.commits(@ref, limit: 2000, skip_merges: true)
    @commits_graph = Gitlab::Graphs::Commits.new(@commits)
    @commits_per_week_days = @commits_graph.commits_per_week_days
    @commits_per_time = @commits_graph.commits_per_time
    @commits_per_month = @commits_graph.commits_per_month
  end

  def get_languages
    @languages = Linguist::Repository.new(@repository.rugged, @repository.rugged.head.target_id).languages
    total = @languages.map(&:last).sum

    @languages = @languages.map do |language|
      name, share = language
      color = Linguist::Language[name].color || "##{Digest::SHA256.hexdigest(name)[0...6]}"
      {
        value: (share.to_f * 100 / total).round(2),
        label: name,
        color: color,
        highlight: color
      }
    end

    @languages.sort! do |x, y|
      y[:value] <=> x[:value]
    end
  end

  def fetch_graph
    @commits = @project.repository.commits(@ref, limit: 6000, skip_merges: true)
    @log = []

    @commits.each do |commit|
      @log << {
        author_name: commit.author_name,
        author_email: commit.author_email,
        date: commit.committed_date.strftime("%Y-%m-%d")
      }
    end

    render json: @log.to_json
  end
end
