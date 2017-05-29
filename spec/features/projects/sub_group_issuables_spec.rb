require 'spec_helper'

describe 'Subgroup Issuables', :feature, :js do
  let!(:group)    { create(:group, name: 'group') }
  let!(:subgroup) { create(:group, parent: group, name: 'subgroup') }
  let!(:project)  { create(:empty_project, namespace: subgroup, name: 'project') }
  let(:user)      { create(:user) }

  before do
    project.add_master(user)
    login_as user
  end

  it 'shows the full subgroup title when issues index page is empty' do
    visit namespace_project_issues_path(project.namespace.to_param, project.to_param)

    expect_to_have_full_subgroup_title
  end

  it 'shows the full subgroup title when merge requests index page is empty' do
    visit namespace_project_merge_requests_path(project.namespace.to_param, project.to_param)

    expect_to_have_full_subgroup_title
  end

  def expect_to_have_full_subgroup_title
    title = find('.title-container')

    expect(title).not_to have_selector '.initializing'
    expect(title).to have_content 'group / subgroup / project'
  end
end
