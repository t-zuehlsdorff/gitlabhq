require 'spec_helper'

describe 'Project deploy keys', :js, :feature do
  let(:user) { create(:user) }
  let(:project) { create(:project_empty_repo) }

  before do
    project.team << [user, :master]
    login_as(user)
  end

  describe 'removing key' do
    before do
      create(:deploy_keys_project, project: project)
    end

    it 'removes association between project and deploy key' do
      visit namespace_project_settings_repository_path(project.namespace, project)

      page.within(find('.deploy-keys')) do
        expect(page).to have_selector('.deploy-keys li', count: 1)

        click_on 'Remove'

        expect(page).not_to have_selector('.fa-spinner', count: 0)
        expect(page).to have_selector('.deploy-keys li', count: 0)
      end
    end
  end
end
