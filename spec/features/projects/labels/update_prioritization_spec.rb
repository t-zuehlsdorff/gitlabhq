require 'spec_helper'

feature 'Prioritize labels', feature: true do
  include DragTo

  let(:user)     { create(:user) }
  let(:group)    { create(:group) }
  let(:project)  { create(:empty_project, :public, namespace: group) }
  let!(:bug)     { create(:label, project: project, title: 'bug') }
  let!(:wontfix) { create(:label, project: project, title: 'wontfix') }
  let!(:feature) { create(:group_label, group: group, title: 'feature') }

  context 'when user belongs to project team' do
    before do
      project.team << [user, :developer]

      login_as user
    end

    scenario 'user can prioritize a group label', js: true do
      visit namespace_project_labels_path(project.namespace, project)

      expect(page).to have_content('Star labels to start sorting by priority')

      page.within('.other-labels') do
        all('.js-toggle-priority')[1].click
        wait_for_requests
        expect(page).not_to have_content('feature')
      end

      page.within('.prioritized-labels') do
        expect(page).not_to have_content('Star labels to start sorting by priority')
        expect(page).to have_content('feature')
      end
    end

    scenario 'user can unprioritize a group label', js: true do
      create(:label_priority, project: project, label: feature, priority: 1)

      visit namespace_project_labels_path(project.namespace, project)

      page.within('.prioritized-labels') do
        expect(page).to have_content('feature')

        first('.js-toggle-priority').click
        wait_for_requests
        expect(page).not_to have_content('bug')
      end

      page.within('.other-labels') do
        expect(page).to have_content('feature')
      end
    end

    scenario 'user can prioritize a project label', js: true do
      visit namespace_project_labels_path(project.namespace, project)

      expect(page).to have_content('Star labels to start sorting by priority')

      page.within('.other-labels') do
        first('.js-toggle-priority').click
        wait_for_requests
        expect(page).not_to have_content('bug')
      end

      page.within('.prioritized-labels') do
        expect(page).not_to have_content('Star labels to start sorting by priority')
        expect(page).to have_content('bug')
      end
    end

    scenario 'user can unprioritize a project label', js: true do
      create(:label_priority, project: project, label: bug, priority: 1)

      visit namespace_project_labels_path(project.namespace, project)

      page.within('.prioritized-labels') do
        expect(page).to have_content('bug')

        first('.js-toggle-priority').click
        wait_for_requests
        expect(page).not_to have_content('bug')
      end

      page.within('.other-labels') do
        expect(page).to have_content('bug')
        expect(page).to have_content('wontfix')
      end
    end

    scenario 'user can sort prioritized labels and persist across reloads', js: true do
      create(:label_priority, project: project, label: bug, priority: 1)
      create(:label_priority, project: project, label: feature, priority: 2)

      visit namespace_project_labels_path(project.namespace, project)

      expect(page).to have_content 'bug'
      expect(page).to have_content 'feature'
      expect(page).to have_content 'wontfix'

      # Sort labels
      drag_to(selector: '.js-prioritized-labels', from_index: 1, to_index: 2)

      page.within('.prioritized-labels') do
        expect(first('li')).to have_content('feature')
        expect(page.all('li').last).to have_content('bug')
      end

      refresh
      wait_for_requests

      page.within('.prioritized-labels') do
        expect(first('li')).to have_content('feature')
        expect(page.all('li').last).to have_content('bug')
      end
    end
  end

  context 'as a guest' do
    it 'does not prioritize labels' do
      guest = create(:user)

      login_as guest

      visit namespace_project_labels_path(project.namespace, project)

      expect(page).to have_content 'bug'
      expect(page).to have_content 'wontfix'
      expect(page).to have_content 'feature'
      expect(page).not_to have_css('.prioritized-labels')
    end
  end

  context 'as a non signed in user' do
    it 'does not prioritize labels' do
      visit namespace_project_labels_path(project.namespace, project)

      expect(page).to have_content 'bug'
      expect(page).to have_content 'wontfix'
      expect(page).to have_content 'feature'
      expect(page).not_to have_css('.prioritized-labels')
    end
  end
end
