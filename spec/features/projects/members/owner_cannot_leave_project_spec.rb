require 'spec_helper'

feature 'Projects > Members > Owner cannot leave project', feature: true do
  let(:project) { create(:project) }

  background do
    gitlab_sign_in(project.owner)
    visit namespace_project_path(project.namespace, project)
  end

  scenario 'user does not see a "Leave project" link' do
    expect(page).not_to have_content 'Leave project'
  end
end
