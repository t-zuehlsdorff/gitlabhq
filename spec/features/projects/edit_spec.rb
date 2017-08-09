require 'rails_helper'

feature 'Project edit', js: true do
  let(:user)    { create(:user) }
  let(:project) { create(:project) }

  before do
    project.team << [user, :master]
    sign_in(user)

    visit edit_project_path(project)
  end

  context 'feature visibility' do
    context 'merge requests select' do
      it 'hides merge requests section' do
        select('Disabled', from: 'project_project_feature_attributes_merge_requests_access_level')

        expect(page).to have_selector('.merge-requests-feature', visible: false)
      end

      context 'given project with merge_requests_disabled access level' do
        let(:project) { create(:project, :merge_requests_disabled) }

        it 'hides merge requests section' do
          expect(page).to have_selector('.merge-requests-feature', visible: false)
        end
      end
    end

    context 'builds select' do
      it 'hides builds select section' do
        select('Disabled', from: 'project_project_feature_attributes_builds_access_level')

        expect(page).to have_selector('.builds-feature', visible: false)
      end

      context 'given project with builds_disabled access level' do
        let(:project) { create(:project, :builds_disabled) }

        it 'hides builds select section' do
          expect(page).to have_selector('.builds-feature', visible: false)
        end
      end
    end
  end
end
