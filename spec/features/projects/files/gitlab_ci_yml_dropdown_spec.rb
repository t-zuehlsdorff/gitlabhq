require 'spec_helper'

feature 'User wants to add a .gitlab-ci.yml file' do
  before do
    user = create(:user)
    project = create(:project, :repository)
    project.team << [user, :master]
    sign_in user
    visit project_new_blob_path(project, 'master', file_name: '.gitlab-ci.yml')
  end

  scenario 'user can see .gitlab-ci.yml dropdown' do
    expect(page).to have_css('.gitlab-ci-yml-selector')
  end

  scenario 'user can pick a template from the dropdown', js: true do
    find('.js-gitlab-ci-yml-selector').click
    wait_for_requests
    within '.gitlab-ci-yml-selector' do
      find('.dropdown-input-field').set('Jekyll')
      find('.dropdown-content li', text: 'Jekyll').click
    end
    wait_for_requests

    expect(page).to have_css('.gitlab-ci-yml-selector .dropdown-toggle-text', text: 'Jekyll')
    expect(page).to have_content('This file is a template, and might need editing before it works on your project')
    expect(page).to have_content('jekyll build -d test')
  end
end
