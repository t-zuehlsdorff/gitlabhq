require 'spec_helper'

describe Gitlab::GitAccessWiki do
  let(:access) { described_class.new(user, project, 'web', authentication_abilities: authentication_abilities, redirected_path: redirected_path) }
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:redirected_path) { nil }
  let(:authentication_abilities) do
    [
      :read_project,
      :download_code,
      :push_code
    ]
  end

  describe 'push_allowed?' do
    before do
      create(:protected_branch, name: 'master', project: project)
      project.team << [user, :developer]
    end

    subject { access.check('git-receive-pack', changes) }

    it { expect { subject }.not_to raise_error }
  end

  def changes
    ['6f6d7e7ed 570e7b2ab refs/heads/master']
  end

  describe '#access_check_download!' do
    subject { access.check('git-upload-pack', '_any') }

    before do
      project.team << [user, :developer]
    end

    context 'when wiki feature is enabled' do
      it 'give access to download wiki code' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when wiki feature is disabled' do
      it 'does not give access to download wiki code' do
        project.project_feature.update_attribute(:wiki_access_level, ProjectFeature::DISABLED)

        expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to download code from this project.')
      end
    end
  end
end
