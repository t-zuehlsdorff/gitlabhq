require 'spec_helper'

feature 'Users', js: true do
  let(:user) { create(:user, username: 'user1', name: 'User 1', email: 'user1@gitlab.com') }

  scenario 'GET /users/sign_in creates a new user account' do
    visit new_user_session_path
    click_link 'Register'
    fill_in 'new_user_name',                with: 'Name Surname'
    fill_in 'new_user_username',            with: 'Great'
    fill_in 'new_user_email',               with: 'name@mail.com'
    fill_in 'new_user_email_confirmation',  with: 'name@mail.com'
    fill_in 'new_user_password',            with: 'password1234'
    expect { click_button 'Register' }.to change { User.count }.by(1)
  end

  scenario 'Successful user signin invalidates password reset token' do
    expect(user.reset_password_token).to be_nil

    visit new_user_password_path
    fill_in 'user_email', with: user.email
    click_button 'Reset password'

    user.reload
    expect(user.reset_password_token).not_to be_nil

    gitlab_sign_in(user)
    expect(current_path).to eq root_path

    user.reload
    expect(user.reset_password_token).to be_nil
  end

  scenario 'Should show one error if email is already taken' do
    visit new_user_session_path
    click_link 'Register'
    fill_in 'new_user_name',                with: 'Another user name'
    fill_in 'new_user_username',            with: 'anotheruser'
    fill_in 'new_user_email',               with: user.email
    fill_in 'new_user_email_confirmation',  with: user.email
    fill_in 'new_user_password',            with: '12341234'
    expect { click_button 'Register' }.to change { User.count }.by(0)
    expect(page).to have_text('Email has already been taken')
    expect(number_of_errors_on_page(page)).to be(1), 'errors on page:\n #{errors_on_page page}'
  end

  describe 'redirect alias routes' do
    before do
      expect(user).to be_persisted
    end

    scenario '/u/user1 redirects to user page' do
      visit '/u/user1'

      expect(current_path).to eq user_path(user)
      expect(page).to have_text(user.name)
    end

    scenario '/u/user1/groups redirects to user groups page' do
      visit '/u/user1/groups'

      expect(current_path).to eq user_groups_path(user)
    end

    scenario '/u/user1/projects redirects to user projects page' do
      visit '/u/user1/projects'

      expect(current_path).to eq user_projects_path(user)
    end
  end

  feature 'username validation' do
    let(:loading_icon) { '.fa.fa-spinner' }
    let(:username_input) { 'new_user_username' }

    before do
      visit new_user_session_path
      click_link 'Register'
    end

    scenario 'doesn\'t show an error border if the username is available' do
      fill_in username_input, with: 'new-user'
      wait_for_requests
      expect(find('.username')).not_to have_css '.gl-field-error-outline'
    end

    scenario 'does not show an error border if the username contains dots (.)' do
      fill_in username_input, with: 'new.user.username'
      wait_for_requests
      expect(find('.username')).not_to have_css '.gl-field-error-outline'
    end

    scenario 'shows an error border if the username already exists' do
      fill_in username_input, with: user.username
      wait_for_requests
      expect(find('.username')).to have_css '.gl-field-error-outline'
    end

    scenario 'shows an  error border if the username contains special characters' do
      fill_in username_input, with: 'new$user!username'
      wait_for_requests
      expect(find('.username')).to have_css '.gl-field-error-outline'
    end
  end

  def errors_on_page(page)
    page.find('#error_explanation').find('ul').all('li').map { |item| item.text }.join("\n")
  end

  def number_of_errors_on_page(page)
    page.find('#error_explanation').find('ul').all('li').count
  end
end
