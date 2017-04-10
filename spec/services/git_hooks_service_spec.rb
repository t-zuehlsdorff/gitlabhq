require 'spec_helper'

describe GitHooksService, services: true do
  include RepoHelpers

  let(:user)    { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:service) { GitHooksService.new }

  before do
    @blankrev = Gitlab::Git::BLANK_SHA
    @oldrev = sample_commit.parent_id
    @newrev = sample_commit.id
    @ref = 'refs/heads/feature'
    @repo_path = project.repository.path_to_repo
  end

  describe '#execute' do
    context 'when receive hooks were successful' do
      it 'calls post-receive hook' do
        hook = double(trigger: [true, nil])
        expect(Gitlab::Git::Hook).to receive(:new).exactly(3).times.and_return(hook)

        service.execute(user, @repo_path, @blankrev, @newrev, @ref) { }
      end
    end

    context 'when pre-receive hook failed' do
      it 'does not call post-receive hook' do
        expect(service).to receive(:run_hook).with('pre-receive').and_return([false, ''])
        expect(service).not_to receive(:run_hook).with('post-receive')

        expect do
          service.execute(user, @repo_path, @blankrev, @newrev, @ref)
        end.to raise_error(GitHooksService::PreReceiveError)
      end
    end

    context 'when update hook failed' do
      it 'does not call post-receive hook' do
        expect(service).to receive(:run_hook).with('pre-receive').and_return([true, nil])
        expect(service).to receive(:run_hook).with('update').and_return([false, ''])
        expect(service).not_to receive(:run_hook).with('post-receive')

        expect do
          service.execute(user, @repo_path, @blankrev, @newrev, @ref)
        end.to raise_error(GitHooksService::PreReceiveError)
      end
    end
  end
end
