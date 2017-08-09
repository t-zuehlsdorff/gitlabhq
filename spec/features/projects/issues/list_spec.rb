require 'spec_helper'

feature 'Issues List' do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  background do
    project.team << [user, :developer]

    sign_in(user)
  end

  scenario 'user does not see create new list button' do
    create(:issue, project: project)

    visit project_issues_path(project)

    expect(page).not_to have_selector('.js-new-board-list')
  end
end
