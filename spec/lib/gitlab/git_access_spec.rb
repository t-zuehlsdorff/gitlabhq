require 'spec_helper'

describe Gitlab::GitAccess do
  let(:pull_access_check) { access.check('git-upload-pack', '_any') }
  let(:push_access_check) { access.check('git-receive-pack', '_any') }
  let(:access) { described_class.new(actor, project, protocol, authentication_abilities: authentication_abilities, redirected_path: redirected_path) }
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:actor) { user }
  let(:protocol) { 'ssh' }
  let(:redirected_path) { nil }
  let(:authentication_abilities) do
    [
      :read_project,
      :download_code,
      :push_code
    ]
  end

  describe '#check with single protocols allowed' do
    def disable_protocol(protocol)
      allow(Gitlab::ProtocolAccess).to receive(:allowed?).with(protocol).and_return(false)
    end

    context 'ssh disabled' do
      before do
        disable_protocol('ssh')
      end

      it 'blocks ssh git push' do
        expect { push_access_check }.to raise_unauthorized('Git access over SSH is not allowed')
      end

      it 'blocks ssh git pull' do
        expect { pull_access_check }.to raise_unauthorized('Git access over SSH is not allowed')
      end
    end

    context 'http disabled' do
      let(:protocol) { 'http' }

      before do
        disable_protocol('http')
      end

      it 'blocks http push' do
        expect { push_access_check }.to raise_unauthorized('Git access over HTTP is not allowed')
      end

      it 'blocks http git pull' do
        expect { pull_access_check }.to raise_unauthorized('Git access over HTTP is not allowed')
      end
    end
  end

  describe '#check_project_accessibility!' do
    context 'when the project exists' do
      context 'when actor exists' do
        context 'when actor is a DeployKey' do
          let(:deploy_key) { create(:deploy_key, user: user, can_push: true) }
          let(:actor) { deploy_key }

          context 'when the DeployKey has access to the project' do
            before do
              deploy_key.projects << project
            end

            it 'allows pull access' do
              expect { pull_access_check }.not_to raise_error
            end

            it 'allows push access' do
              expect { push_access_check }.not_to raise_error
            end
          end

          context 'when the Deploykey does not have access to the project' do
            it 'blocks pulls with "not found"' do
              expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.')
            end

            it 'blocks pushes with "not found"' do
              expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.')
            end
          end
        end

        context 'when actor is a User' do
          context 'when the User can read the project' do
            before do
              project.team << [user, :master]
            end

            it 'allows pull access' do
              expect { pull_access_check }.not_to raise_error
            end

            it 'allows push access' do
              expect { push_access_check }.not_to raise_error
            end
          end

          context 'when the User cannot read the project' do
            it 'blocks pulls with "not found"' do
              expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.')
            end

            it 'blocks pushes with "not found"' do
              expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.')
            end
          end
        end

        # For backwards compatibility
        context 'when actor is :ci' do
          let(:actor) { :ci }
          let(:authentication_abilities) { build_authentication_abilities }

          it 'allows pull access' do
            expect { pull_access_check }.not_to raise_error
          end

          it 'does not block pushes with "not found"' do
            expect { push_access_check }.to raise_unauthorized('You are not allowed to upload code for this project.')
          end
        end
      end

      context 'when actor is nil' do
        let(:actor) { nil }

        context 'when guests can read the project' do
          let(:project) { create(:project, :repository, :public) }

          it 'allows pull access' do
            expect { pull_access_check }.not_to raise_error
          end

          it 'does not block pushes with "not found"' do
            expect { push_access_check }.to raise_unauthorized('You are not allowed to upload code for this project.')
          end
        end

        context 'when guests cannot read the project' do
          it 'blocks pulls with "not found"' do
            expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.')
          end

          it 'blocks pushes with "not found"' do
            expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.')
          end
        end
      end
    end

    context 'when the project is nil' do
      let(:project) { nil }

      it 'blocks any command with "not found"' do
        expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.')
        expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.')
      end
    end
  end

  describe '#check_project_moved!' do
    before do
      project.team << [user, :master]
    end

    context 'when a redirect was not followed to find the project' do
      context 'pull code' do
        it { expect { pull_access_check }.not_to raise_error }
      end

      context 'push code' do
        it { expect { push_access_check }.not_to raise_error }
      end
    end

    context 'when a redirect was followed to find the project' do
      let(:redirected_path) { 'some/other-path' }

      context 'pull code' do
        it { expect { pull_access_check }.to raise_not_found(/Project '#{redirected_path}' was moved to '#{project.full_path}'/) }
        it { expect { pull_access_check }.to raise_not_found(/git remote set-url origin #{project.ssh_url_to_repo}/) }

        context 'http protocol' do
          let(:protocol) { 'http' }
          it { expect { pull_access_check }.to raise_not_found(/git remote set-url origin #{project.http_url_to_repo}/) }
        end
      end

      context 'push code' do
        it { expect { push_access_check }.to raise_not_found(/Project '#{redirected_path}' was moved to '#{project.full_path}'/) }
        it { expect { push_access_check }.to raise_not_found(/git remote set-url origin #{project.ssh_url_to_repo}/) }

        context 'http protocol' do
          let(:protocol) { 'http' }
          it { expect { push_access_check }.to raise_not_found(/git remote set-url origin #{project.http_url_to_repo}/) }
        end
      end
    end
  end

  describe '#check_command_disabled!' do
    before do
      project.team << [user, :master]
    end

    context 'over http' do
      let(:protocol) { 'http' }

      context 'when the git-upload-pack command is disabled in config' do
        before do
          allow(Gitlab.config.gitlab_shell).to receive(:upload_pack).and_return(false)
        end

        context 'when calling git-upload-pack' do
          it { expect { pull_access_check }.to raise_unauthorized('Pulling over HTTP is not allowed.') }
        end

        context 'when calling git-receive-pack' do
          it { expect { push_access_check }.not_to raise_error }
        end
      end

      context 'when the git-receive-pack command is disabled in config' do
        before do
          allow(Gitlab.config.gitlab_shell).to receive(:receive_pack).and_return(false)
        end

        context 'when calling git-receive-pack' do
          it { expect { push_access_check }.to raise_unauthorized('Pushing over HTTP is not allowed.') }
        end

        context 'when calling git-upload-pack' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end
    end
  end

  describe '#check_download_access!' do
    describe 'master permissions' do
      before do
        project.team << [user, :master]
      end

      context 'pull code' do
        it { expect { pull_access_check }.not_to raise_error }
      end
    end

    describe 'guest permissions' do
      before do
        project.team << [user, :guest]
      end

      context 'pull code' do
        it { expect { pull_access_check }.to raise_unauthorized('You are not allowed to download code from this project.') }
      end
    end

    describe 'blocked user' do
      before do
        project.team << [user, :master]
        user.block
      end

      context 'pull code' do
        it { expect { pull_access_check }.to raise_unauthorized('Your account has been blocked.') }
      end
    end

    describe 'without access to project' do
      context 'pull code' do
        it { expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.') }
      end

      context 'when project is public' do
        let(:public_project) { create(:project, :public, :repository) }
        let(:access) { described_class.new(nil, public_project, 'web', authentication_abilities: []) }

        context 'when repository is enabled' do
          it 'give access to download code' do
            expect { pull_access_check }.not_to raise_error
          end
        end

        context 'when repository is disabled' do
          it 'does not give access to download code' do
            public_project.project_feature.update_attribute(:repository_access_level, ProjectFeature::DISABLED)

            expect { pull_access_check }.to raise_unauthorized('You are not allowed to download code from this project.')
          end
        end
      end
    end

    describe 'deploy key permissions' do
      let(:key) { create(:deploy_key, user: user) }
      let(:actor) { key }

      context 'pull code' do
        context 'when project is authorized' do
          before do
            key.projects << project
          end

          it { expect { pull_access_check }.not_to raise_error }
        end

        context 'when unauthorized' do
          context 'from public project' do
            let(:project) { create(:project, :public, :repository) }

            it { expect { pull_access_check }.not_to raise_error }
          end

          context 'from internal project' do
            let(:project) { create(:project, :internal, :repository) }

            it { expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.') }
          end

          context 'from private project' do
            let(:project) { create(:project, :private, :repository) }

            it { expect { pull_access_check }.to raise_not_found('The project you were looking for could not be found.') }
          end
        end
      end
    end

    describe 'build authentication_abilities permissions' do
      let(:authentication_abilities) { build_authentication_abilities }

      describe 'owner' do
        let(:project) { create(:project, :repository, namespace: user.namespace) }

        context 'pull code' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end

      describe 'reporter user' do
        before do
          project.team << [user, :reporter]
        end

        context 'pull code' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end

      describe 'admin user' do
        let(:user) { create(:admin) }

        context 'when member of the project' do
          before do
            project.team << [user, :reporter]
          end

          context 'pull code' do
            it { expect { pull_access_check }.not_to raise_error }
          end
        end

        context 'when is not member of the project' do
          context 'pull code' do
            it { expect { pull_access_check }.to raise_unauthorized('You are not allowed to download code from this project.') }
          end
        end
      end

      describe 'generic CI (build without a user)' do
        let(:actor) { :ci }

        context 'pull code' do
          it { expect { pull_access_check }.not_to raise_error }
        end
      end
    end
  end

  describe '#check_push_access!' do
    before do
      merge_into_protected_branch
    end
    let(:unprotected_branch) { 'unprotected_branch' }

    let(:changes) do
      { push_new_branch: "#{Gitlab::Git::BLANK_SHA} 570e7b2ab refs/heads/wow",
        push_master: '6f6d7e7ed 570e7b2ab refs/heads/master',
        push_protected_branch: '6f6d7e7ed 570e7b2ab refs/heads/feature',
        push_remove_protected_branch: "570e7b2ab #{Gitlab::Git::BLANK_SHA} "\
                                      'refs/heads/feature',
        push_tag: '6f6d7e7ed 570e7b2ab refs/tags/v1.0.0',
        push_new_tag: "#{Gitlab::Git::BLANK_SHA} 570e7b2ab refs/tags/v7.8.9",
        push_all: ['6f6d7e7ed 570e7b2ab refs/heads/master', '6f6d7e7ed 570e7b2ab refs/heads/feature'],
        merge_into_protected_branch: "0b4bc9a #{merge_into_protected_branch} refs/heads/feature" }
    end

    def stub_git_hooks
      # Running the `pre-receive` hook is expensive, and not necessary for this test.
      allow_any_instance_of(GitHooksService).to receive(:execute) do |service, &block|
        block.call(service)
      end
    end

    def merge_into_protected_branch
      @protected_branch_merge_commit ||= begin
        stub_git_hooks
        project.repository.add_branch(user, unprotected_branch, 'feature')
        target_branch = project.repository.lookup('feature')
        source_branch = project.repository.create_file(
          user,
          'filename',
          'This is the file content',
          message: 'This is a good commit message',
          branch_name: unprotected_branch)
        rugged = project.repository.rugged
        author = { email: "email@example.com", time: Time.now, name: "Example Git User" }

        merge_index = rugged.merge_commits(target_branch, source_branch)
        Rugged::Commit.create(rugged, author: author, committer: author, message: "commit message", parents: [target_branch, source_branch], tree: merge_index.write_tree(rugged))
      end
    end

    # Run permission checks for a user
    def self.run_permission_checks(permissions_matrix)
      permissions_matrix.keys.each do |role|
        describe "#{role} access" do
          before do
            if role == :admin
              user.update_attribute(:admin, true)
            else
              project.team << [user, role]
            end
          end

          permissions_matrix[role].each do |action, allowed|
            context action.to_s do
              subject { access.send(:check_push_access!, changes[action]) }

              it do
                if allowed
                  expect { subject }.not_to raise_error
                else
                  expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError)
                end
              end
            end
          end
        end
      end
    end

    permissions_matrix = {
      admin: {
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      master: {
        push_new_branch: true,
        push_master: true,
        push_protected_branch: true,
        push_remove_protected_branch: false,
        push_tag: true,
        push_new_tag: true,
        push_all: true,
        merge_into_protected_branch: true
      },

      developer: {
        push_new_branch: true,
        push_master: true,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: true,
        push_all: false,
        merge_into_protected_branch: false
      },

      reporter: {
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      },

      guest: {
        push_new_branch: false,
        push_master: false,
        push_protected_branch: false,
        push_remove_protected_branch: false,
        push_tag: false,
        push_new_tag: false,
        push_all: false,
        merge_into_protected_branch: false
      }
    }

    [%w(feature exact), ['feat*', 'wildcard']].each do |protected_branch_name, protected_branch_type|
      context do
        before do
          create(:protected_branch, name: protected_branch_name, project: project)
        end

        run_permission_checks(permissions_matrix)
      end

      context "when developers are allowed to push into the #{protected_branch_type} protected branch" do
        before do
          create(:protected_branch, :developers_can_push, name: protected_branch_name, project: project)
        end

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true }))
      end

      context "developers are allowed to merge into the #{protected_branch_type} protected branch" do
        before do
          create(:protected_branch, :developers_can_merge, name: protected_branch_name, project: project)
        end

        context "when a merge request exists for the given source/target branch" do
          context "when the merge request is in progress" do
            before do
              create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature',
                                     state: 'locked', in_progress_merge_commit_sha: merge_into_protected_branch)
            end

            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: true }))
          end

          context "when the merge request is not in progress" do
            before do
              create(:merge_request, source_project: project, source_branch: unprotected_branch, target_branch: 'feature', in_progress_merge_commit_sha: nil)
            end

            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: false }))
          end

          context "when a merge request does not exist for the given source/target branch" do
            run_permission_checks(permissions_matrix.deep_merge(developer: { merge_into_protected_branch: false }))
          end
        end
      end

      context "when developers are allowed to push and merge into the #{protected_branch_type} protected branch" do
        before do
          create(:protected_branch, :developers_can_merge, :developers_can_push, name: protected_branch_name, project: project)
        end

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: true, push_all: true, merge_into_protected_branch: true }))
      end

      context "when no one is allowed to push to the #{protected_branch_name} protected branch" do
        before do
          create(:protected_branch, :no_one_can_push, name: protected_branch_name, project: project)
        end

        run_permission_checks(permissions_matrix.deep_merge(developer: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false },
                                                            master: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false },
                                                            admin: { push_protected_branch: false, push_all: false, merge_into_protected_branch: false }))
      end
    end
  end

  describe 'build authentication abilities' do
    let(:authentication_abilities) { build_authentication_abilities }

    context 'when project is authorized' do
      before do
        project.team << [user, :reporter]
      end

      it { expect { push_access_check }.to raise_unauthorized('You are not allowed to upload code for this project.') }
    end

    context 'when unauthorized' do
      context 'to public project' do
        let(:project) { create(:project, :public, :repository) }

        it { expect { push_access_check }.to raise_unauthorized('You are not allowed to upload code for this project.') }
      end

      context 'to internal project' do
        let(:project) { create(:project, :internal, :repository) }

        it { expect { push_access_check }.to raise_unauthorized('You are not allowed to upload code for this project.') }
      end

      context 'to private project' do
        let(:project) { create(:project, :private, :repository) }

        it { expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.') }
      end
    end
  end

  describe 'deploy key permissions' do
    let(:key) { create(:deploy_key, user: user, can_push: can_push) }
    let(:actor) { key }

    context 'when deploy_key can push' do
      let(:can_push) { true }

      context 'when project is authorized' do
        before do
          key.projects << project
        end

        it { expect { push_access_check }.not_to raise_error }
      end

      context 'when unauthorized' do
        context 'to public project' do
          let(:project) { create(:project, :public, :repository) }

          it { expect { push_access_check }.to raise_unauthorized('This deploy key does not have write access to this project.') }
        end

        context 'to internal project' do
          let(:project) { create(:project, :internal, :repository) }

          it { expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.') }
        end

        context 'to private project' do
          let(:project) { create(:project, :private, :repository) }

          it { expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.') }
        end
      end
    end

    context 'when deploy_key cannot push' do
      let(:can_push) { false }

      context 'when project is authorized' do
        before do
          key.projects << project
        end

        it { expect { push_access_check }.to raise_unauthorized('This deploy key does not have write access to this project.') }
      end

      context 'when unauthorized' do
        context 'to public project' do
          let(:project) { create(:project, :public, :repository) }

          it { expect { push_access_check }.to raise_unauthorized('This deploy key does not have write access to this project.') }
        end

        context 'to internal project' do
          let(:project) { create(:project, :internal, :repository) }

          it { expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.') }
        end

        context 'to private project' do
          let(:project) { create(:project, :private, :repository) }

          it { expect { push_access_check }.to raise_not_found('The project you were looking for could not be found.') }
        end
      end
    end
  end

  private

  def raise_unauthorized(message)
    raise_error(Gitlab::GitAccess::UnauthorizedError, message)
  end

  def raise_not_found(message)
    raise_error(Gitlab::GitAccess::NotFoundError, message)
  end

  def build_authentication_abilities
    [
      :read_project,
      :build_download_code
    ]
  end

  def full_authentication_abilities
    [
      :read_project,
      :download_code,
      :push_code
    ]
  end
end
