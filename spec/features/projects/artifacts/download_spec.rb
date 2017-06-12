require 'spec_helper'

feature 'Download artifact', :js, feature: true do
  let(:project) { create(:project, :public) }
  let(:pipeline) { create(:ci_empty_pipeline, status: :success, project: project, sha: project.commit.sha, ref: 'master') }
  let(:job) { create(:ci_build, :artifacts, :success, pipeline: pipeline) }

  shared_examples 'downloading' do
    it 'downloads the zip' do
      expect(page.response_headers['Content-Disposition'])
        .to eq(%Q{attachment; filename="#{job.artifacts_file.filename}"})

      # Check the content does match, but don't print this as error message
      expect(page.source.b == job.artifacts_file.file.read.b)
    end
  end

  context 'when downloading' do
    before do
      visit download_url
    end

    context 'via job id' do
      let(:download_url) do
        download_namespace_project_job_artifacts_path(project.namespace, project, job)
      end

      it_behaves_like 'downloading'
    end

    context 'via branch name and job name' do
      let(:download_url) do
        latest_succeeded_namespace_project_artifacts_path(project.namespace, project, "#{pipeline.ref}/download", job: job.name)
      end

      it_behaves_like 'downloading'
    end
  end

  context 'when visiting old URL' do
    before do
      visit download_url.sub('/-/jobs', '/builds')
    end

    context 'via job id' do
      let(:download_url) do
        download_namespace_project_job_artifacts_path(project.namespace, project, job)
      end

      it_behaves_like 'downloading'
    end

    context 'via branch name and job name' do
      let(:download_url) do
        latest_succeeded_namespace_project_artifacts_path(project.namespace, project, "#{pipeline.ref}/download", job: job.name)
      end

      it_behaves_like 'downloading'
    end
  end
end
