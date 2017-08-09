require 'spec_helper'

feature 'Dashboard Issues filtering', :js do
  include SortingHelper

  let(:user)      { create(:user) }
  let(:project)   { create(:project) }
  let(:milestone) { create(:milestone, project: project) }

  let!(:issue)  { create(:issue, project: project, author: user, assignees: [user]) }
  let!(:issue2) { create(:issue, project: project, author: user, assignees: [user], milestone: milestone) }

  before do
    project.add_master(user)
    sign_in(user)

    visit_issues
  end

  context 'filtering by milestone' do
    it 'shows all issues with no milestone' do
      show_milestone_dropdown

      click_link 'No Milestone'

      expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)
      expect(page).to have_selector('.issue', count: 1)
    end

    it 'shows all issues with any milestone' do
      show_milestone_dropdown

      click_link 'Any Milestone'

      expect(page).to have_issuable_counts(open: 2, closed: 0, all: 2)
      expect(page).to have_selector('.issue', count: 2)
    end

    it 'shows all issues with the selected milestone' do
      show_milestone_dropdown

      page.within '.dropdown-content' do
        click_link milestone.title
      end

      expect(page).to have_issuable_counts(open: 1, closed: 0, all: 1)
      expect(page).to have_selector('.issue', count: 1)
    end

    it 'updates atom feed link' do
      visit_issues(milestone_title: '', assignee_id: user.id)

      link = find('.nav-controls a[title="Subscribe"]')
      params = CGI.parse(URI.parse(link[:href]).query)
      auto_discovery_link = find('link[type="application/atom+xml"]', visible: false)
      auto_discovery_params = CGI.parse(URI.parse(auto_discovery_link[:href]).query)

      expect(params).to include('rss_token' => [user.rss_token])
      expect(params).to include('milestone_title' => [''])
      expect(params).to include('assignee_id' => [user.id.to_s])
      expect(auto_discovery_params).to include('rss_token' => [user.rss_token])
      expect(auto_discovery_params).to include('milestone_title' => [''])
      expect(auto_discovery_params).to include('assignee_id' => [user.id.to_s])
    end
  end

  context 'filtering by label' do
    let(:label) { create(:label, project: project) }
    let!(:label_link) { create(:label_link, label: label, target: issue) }

    it 'shows all issues without filter' do
      page.within 'ul.content-list' do
        expect(page).to have_content issue.title
        expect(page).to have_content issue2.title
      end
    end

    it 'shows all issues with the selected label' do
      page.within '.labels-filter' do
        find('.dropdown').click
        click_link label.title
      end

      page.within 'ul.content-list' do
        expect(page).to have_content issue.title
        expect(page).not_to have_content issue2.title
      end
    end
  end

  context 'sorting' do
    it 'shows sorted issues' do
      sorting_by('Oldest updated')
      visit_issues

      expect(find('.issues-filters')).to have_content('Oldest updated')
    end

    it 'keeps sorting issues after visiting Projects Issues page' do
      sorting_by('Oldest updated')
      visit project_issues_path(project)

      expect(find('.issues-filters')).to have_content('Oldest updated')
    end
  end

  def show_milestone_dropdown
    click_button 'Milestone'
    expect(page).to have_selector('.dropdown-content', visible: true)
  end

  def visit_issues(*args)
    visit issues_dashboard_path(*args)
  end
end
