require 'spec_helper'

feature 'Edit group settings', feature: true do
  given(:user)  { create(:user) }
  given(:group) { create(:group, path: 'foo') }

  background do
    group.add_owner(user)
    login_as(user)
  end

  describe 'when the group path is changed' do
    let(:new_group_path) { 'bar' }
    let(:old_group_full_path) { "/#{group.path}" }
    let(:new_group_full_path) { "/#{new_group_path}" }

    scenario 'the group is accessible via the new path' do
      update_path(new_group_path)
      visit new_group_full_path
      expect(current_path).to eq(new_group_full_path)
      expect(find('h1.group-title')).to have_content(new_group_path)
    end

    scenario 'the old group path redirects to the new path' do
      update_path(new_group_path)
      visit old_group_full_path
      expect(current_path).to eq(new_group_full_path)
      expect(find('h1.group-title')).to have_content(new_group_path)
    end

    context 'with a subgroup' do
      given!(:subgroup) { create(:group, parent: group, path: 'subgroup') }
      given(:old_subgroup_full_path) { "/#{group.path}/#{subgroup.path}" }
      given(:new_subgroup_full_path) { "/#{new_group_path}/#{subgroup.path}" }

      scenario 'the subgroup is accessible via the new path' do
        update_path(new_group_path)
        visit new_subgroup_full_path
        expect(current_path).to eq(new_subgroup_full_path)
        expect(find('h1.group-title')).to have_content(subgroup.path)
      end

      scenario 'the old subgroup path redirects to the new path' do
        update_path(new_group_path)
        visit old_subgroup_full_path
        expect(current_path).to eq(new_subgroup_full_path)
        expect(find('h1.group-title')).to have_content(subgroup.path)
      end
    end

    context 'with a project' do
      given!(:project) { create(:project, group: group, path: 'project') }
      given(:old_project_full_path) { "/#{group.path}/#{project.path}" }
      given(:new_project_full_path) { "/#{new_group_path}/#{project.path}" }
      
      before(:context) { TestEnv.clean_test_path }
      after(:example) { TestEnv.clean_test_path }

      scenario 'the project is accessible via the new path' do
        update_path(new_group_path)
        visit new_project_full_path
        expect(current_path).to eq(new_project_full_path)
        expect(find('h1.project-title')).to have_content(project.name)
      end

      scenario 'the old project path redirects to the new path' do
        update_path(new_group_path)
        visit old_project_full_path
        expect(current_path).to eq(new_project_full_path)
        expect(find('h1.project-title')).to have_content(project.name)
      end
    end
  end
end

def update_path(new_group_path)
  visit edit_group_path(group)
  fill_in 'group_path', with: new_group_path
  click_button 'Save group'
end
