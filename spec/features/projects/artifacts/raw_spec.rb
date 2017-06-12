require 'spec_helper'

feature 'Raw artifact', :js, feature: true do
  let(:project) { create(:project, :public) }
  let(:pipeline) { create(:ci_empty_pipeline, project: project, sha: project.commit.sha, ref: 'master') }
  let(:job) { create(:ci_build, :artifacts, pipeline: pipeline) }

  def raw_path(path)
    raw_namespace_project_job_artifacts_path(project.namespace, project, job, path)
  end

  context 'when visiting old URL' do
    let(:raw_url) do
      raw_path('other_artifacts_0.1.2/doc_sample.txt')
    end

    before do
      visit raw_url.sub('/-/jobs', '/builds')
    end

    it "redirects to new URL" do
      expect(page.current_path).to eq(raw_url)
    end
  end
end
