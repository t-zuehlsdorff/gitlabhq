require 'spec_helper'

describe 'Reportable note on merge request', :feature, :js do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:merge_request) { create(:merge_request, source_project: project) }

  before do
    project.add_master(user)
    login_as user

    visit namespace_project_merge_request_path(project.namespace, project, merge_request)
  end

  context 'a normal note' do
    let!(:note) { create(:note_on_merge_request, noteable: merge_request, project: project) }

    it_behaves_like 'reportable note'
  end

  context 'a diff note' do
    let!(:note) { create(:diff_note_on_merge_request, noteable: merge_request, project: project) }

    it_behaves_like 'reportable note'
  end
end
