require 'rails_helper'

describe ImportHelper do
  describe '#import_project_target' do
    let(:user) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'when current user can create namespaces' do
      it 'returns project namespace' do
        user.update_attribute(:can_create_group, true)

        expect(helper.import_project_target('asd', 'vim')).to eq 'asd/vim'
      end
    end

    context 'when current user can not create namespaces' do
      it "takes the current user's namespace" do
        user.update_attribute(:can_create_group, false)

        expect(helper.import_project_target('asd', 'vim')).to eq "#{user.namespace_path}/vim"
      end
    end
  end

  describe '#provider_project_link' do
    context 'when provider is "github"' do
      context 'when provider does not specify a custom URL' do
        it 'uses default GitHub URL' do
          allow(Gitlab.config.omniauth).to receive(:providers)
          .and_return([Settingslogic.new('name' => 'github')])

          expect(helper.provider_project_link('github', 'octocat/Hello-World'))
          .to include('href="https://github.com/octocat/Hello-World"')
        end
      end

      context 'when provider specify a custom URL' do
        it 'uses custom URL' do
          allow(Gitlab.config.omniauth).to receive(:providers)
          .and_return([Settingslogic.new('name' => 'github', 'url' => 'https://github.company.com')])

          expect(helper.provider_project_link('github', 'octocat/Hello-World'))
          .to include('href="https://github.company.com/octocat/Hello-World"')
        end
      end
    end

    context 'when provider is "gitea"' do
      before do
        assign(:gitea_host_url, 'https://try.gitea.io/')
      end

      it 'uses given host' do
        expect(helper.provider_project_link('gitea', 'octocat/Hello-World'))
        .to include('href="https://try.gitea.io/octocat/Hello-World"')
      end
    end
  end
end
