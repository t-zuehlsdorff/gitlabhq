require 'spec_helper'

describe 'Help Pages', feature: true do
  describe 'Get the main help page' do
    shared_examples_for 'help page' do |prefix: ''|
      it 'prefixes links correctly' do
        expect(page).to have_selector(%(div.documentation-index > ul a[href="#{prefix}/help/api/README.md"]))
      end
    end

    context 'without a trailing slash' do
      before do
        visit help_path
      end

      it_behaves_like 'help page'
    end

    context 'with a trailing slash' do
      before do
        visit help_path + '/'
      end

      it_behaves_like 'help page'
    end

    context 'with a relative installation' do
      before do
        stub_config_setting(relative_url_root: '/gitlab')
        visit help_path
      end

      it_behaves_like 'help page', prefix: '/gitlab'
    end
  end

  context 'in a production environment with version check enabled', :js do
    before do
      allow(Rails.env).to receive(:production?) { true }
      allow(current_application_settings).to receive(:version_check_enabled) { true }
      allow_any_instance_of(VersionCheck).to receive(:url) { '/version-check-url' }

      login_as :user
      visit help_path
    end

    it 'has a version check image' do
      expect(find('.js-version-status-badge', visible: false)['src']).to end_with('/version-check-url')
    end

    it 'hides the version check image if the image request fails' do
      # We use '--load-images=yes' with poltergeist so the image fails to load
      expect(find('.js-version-status-badge', visible: false)).not_to be_visible
    end
  end
end
