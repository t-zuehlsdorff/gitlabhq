require 'spec_helper'

feature 'Setup Jira service', :js do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:service) { project.create_jira_service }

  let(:url) { 'http://jira.example.com' }
  let(:test_url) { 'http://jira.example.com/rest/api/2/serverInfo' }

  def fill_form(active = true)
    check 'Active' if active

    fill_in 'service_url', with: url
    fill_in 'service_username', with: 'username'
    fill_in 'service_password', with: 'password'
    fill_in 'service_jira_issue_transition_id', with: '25'
  end

  before do
    project.team << [user, :master]
    sign_in(user)

    visit project_settings_integrations_path(project)
  end

  describe 'user sets and activates Jira Service' do
    context 'when Jira connection test succeeds' do
      it 'activates the JIRA service' do
        server_info = { key: 'value' }.to_json
        WebMock.stub_request(:get, test_url).with(basic_auth: %w(username password)).to_return(body: server_info)

        click_link('JIRA')
        fill_form
        click_button('Test settings and save changes')
        wait_for_requests

        expect(page).to have_content('JIRA activated.')
        expect(current_path).to eq(project_settings_integrations_path(project))
      end
    end

    context 'when Jira connection test fails' do
      it 'shows errors when some required fields are not filled in' do
        click_link('JIRA')

        check 'Active'
        fill_in 'service_password', with: 'password'
        click_button('Test settings and save changes')

        page.within('.service-settings') do
          expect(page).to have_content('This field is required.')
        end
      end

      it 'activates the JIRA service' do
        WebMock.stub_request(:get, test_url).with(basic_auth: %w(username password))
          .to_raise(JIRA::HTTPError.new(double(message: 'message')))

        click_link('JIRA')
        fill_form
        click_button('Test settings and save changes')
        wait_for_requests

        expect(find('.flash-container-page')).to have_content 'Test failed. message'
        expect(find('.flash-container-page')).to have_content 'Save anyway'

        find('.flash-alert .flash-action').trigger('click')
        wait_for_requests

        expect(page).to have_content('JIRA activated.')
        expect(current_path).to eq(project_settings_integrations_path(project))
      end
    end
  end

  describe 'user sets Jira Service but keeps it disabled' do
    context 'when Jira connection test succeeds' do
      it 'activates the JIRA service' do
        click_link('JIRA')
        fill_form(false)
        click_button('Save changes')

        expect(page).to have_content('JIRA settings saved, but not activated.')
        expect(current_path).to eq(project_settings_integrations_path(project))
      end
    end
  end
end
