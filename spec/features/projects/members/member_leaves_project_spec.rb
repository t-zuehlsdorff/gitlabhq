require 'spec_helper'

feature 'Projects > Members > Member leaves project', feature: true do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  background do
    project.team << [user, :developer]
    gitlab_sign_in(user)
    visit namespace_project_path(project.namespace, project)
  end

  scenario 'user leaves project' do
    click_link 'Leave project'

    expect(current_path).to eq(dashboard_projects_path)
    expect(project.users.exists?(user.id)).to be_falsey
  end
end
