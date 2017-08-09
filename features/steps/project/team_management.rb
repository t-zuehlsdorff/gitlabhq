class Spinach::Features::ProjectTeamManagement < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedProject
  include SharedPaths
  include Select2Helper

  step 'I should not see "Dmitriy" in team list' do
    user = User.find_by(name: "Dmitriy")
    expect(page).not_to have_content(user.name)
    expect(page).not_to have_content(user.username)
  end

  step 'I should see "Mike" in team list as "Reporter"' do
    user = User.find_by(name: 'Mike')
    project_member = project.project_members.find_by(user_id: user.id)
    page.within "#project_member_#{project_member.id}" do
      expect(page).to have_content('Mike')
      expect(page).to have_content('Reporter')
    end
  end

  step 'gitlab user "Mike"' do
    create(:user, name: "Mike")
  end

  step 'gitlab user "Dmitriy"' do
    create(:user, name: "Dmitriy")
  end

  step '"Dmitriy" is "Shop" developer' do
    user = User.find_by(name: "Dmitriy")
    project = Project.find_by(name: "Shop")
    project.team << [user, :developer]
  end

  step 'I own project "Website"' do
    @project = create(:project, name: "Website", namespace: @user.namespace)
    @project.team << [@user, :master]
  end

  step '"Mike" is "Website" reporter' do
    user = User.find_by(name: "Mike")
    project = Project.find_by(name: "Website")
    project.team << [user, :reporter]
  end

  step 'I click link "Import team from another project"' do
    page.within '.users-project-form' do
      click_link "Import"
    end
  end

  When 'I submit "Website" project for import team' do
    project = Project.find_by(name: "Website")
    select project.name_with_namespace, from: 'source_project_id'
    click_button 'Import'
  end

  step 'I click cancel link for "Dmitriy"' do
    project = Project.find_by(name: "Shop")
    user = User.find_by(name: 'Dmitriy')
    project_member = project.project_members.find_by(user_id: user.id)
    page.within "#project_member_#{project_member.id}" do
      click_link('Remove user from project')
    end
  end

  step 'I share project with group "OpenSource"' do
    project = Project.find_by(name: 'Shop')
    os_group = create(:group, name: 'OpenSource')
    create(:project, group: os_group)
    @os_user1 = create(:user)
    @os_user2 = create(:user)
    os_group.add_owner(@os_user1)
    os_group.add_user(@os_user2, Gitlab::Access::DEVELOPER)
    share_link = project.project_group_links.new(group_access: Gitlab::Access::MASTER)
    share_link.group_id = os_group.id
    share_link.save!
  end

  step 'I should see "Opensource" group user listing' do
    page.within '.project-members-groups' do
      expect(page).to have_content('OpenSource')
      expect(first('.group_member')).to have_content('Master')
    end
  end
end
