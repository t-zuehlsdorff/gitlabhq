require 'spec_helper'

describe 'Reportable note on commit', :feature, :js do
  include RepoHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    project.add_master(user)
    login_as user
  end

  context 'a normal note' do
    let!(:note) { create(:note_on_commit, commit_id: sample_commit.id, project: project) }

    before do
      visit namespace_project_commit_path(project.namespace, project, sample_commit.id)
    end

    it_behaves_like 'reportable note'
  end

  context 'a diff note' do
    let!(:note) { create(:diff_note_on_commit, commit_id: sample_commit.id, project: project) }

    before do
      visit namespace_project_commit_path(project.namespace, project, sample_commit.id)
    end

    it_behaves_like 'reportable note'
  end
end
