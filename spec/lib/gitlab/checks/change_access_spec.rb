require 'spec_helper'

describe Gitlab::Checks::ChangeAccess do
  describe '#exec' do
    let(:user) { create(:user) }
    let(:project) { create(:project, :repository) }
    let(:user_access) { Gitlab::UserAccess.new(user, project: project) }
    let(:oldrev) { 'be93687618e4b132087f430a4d8fc3a609c9b77c' }
    let(:newrev) { '54fcc214b94e78d7a41a9a8fe6d87a5e59500e51' }
    let(:ref) { 'refs/heads/master' }
    let(:changes) { { oldrev: oldrev, newrev: newrev, ref: ref } }
    let(:protocol) { 'ssh' }

    subject do
      described_class.new(
        changes,
        project: project,
        user_access: user_access,
        protocol: protocol
      ).exec
    end

    before do
      project.add_developer(user)
    end

    context 'without failed checks' do
      it "doesn't raise an error" do
        expect { subject }.not_to raise_error
      end
    end

    context 'when the user is not allowed to push code' do
      it 'raises an error' do
        expect(user_access).to receive(:can_do_action?).with(:push_code).and_return(false)

        expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to push code to this project.')
      end
    end

    context 'tags check' do
      let(:ref) { 'refs/tags/v1.0.0' }

      it 'raises an error if the user is not allowed to update tags' do
        allow(user_access).to receive(:can_do_action?).with(:push_code).and_return(true)
        expect(user_access).to receive(:can_do_action?).with(:admin_project).and_return(false)

        expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to change existing tags on this project.')
      end

      context 'with protected tag' do
        let!(:protected_tag) { create(:protected_tag, project: project, name: 'v*') }

        context 'as master' do
          before do
            project.add_master(user)
          end

          context 'deletion' do
            let(:oldrev) { 'be93687618e4b132087f430a4d8fc3a609c9b77c' }
            let(:newrev) { '0000000000000000000000000000000000000000' }

            it 'is prevented' do
              expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, /cannot be deleted/)
            end
          end

          context 'update' do
            let(:oldrev) { 'be93687618e4b132087f430a4d8fc3a609c9b77c' }
            let(:newrev) { '54fcc214b94e78d7a41a9a8fe6d87a5e59500e51' }

            it 'is prevented' do
              expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, /cannot be updated/)
            end
          end
        end

        context 'creation' do
          let(:oldrev) { '0000000000000000000000000000000000000000' }
          let(:newrev) { '54fcc214b94e78d7a41a9a8fe6d87a5e59500e51' }
          let(:ref) { 'refs/tags/v9.1.0' }

          it 'prevents creation below access level' do
            expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, /allowed to create this tag as it is protected/)
          end

          context 'when user has access' do
            let!(:protected_tag) { create(:protected_tag, :developers_can_create, project: project, name: 'v*') }

            it 'allows tag creation' do
              expect { subject }.not_to raise_error
            end
          end
        end
      end
    end

    context 'branches check' do
      context 'trying to delete the default branch' do
        let(:newrev) { '0000000000000000000000000000000000000000' }
        let(:ref) { 'refs/heads/master' }

        it 'raises an error' do
          expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'The default branch of a project cannot be deleted.')
        end
      end

      context 'protected branches check' do
        before do
          allow(ProtectedBranch).to receive(:protected?).with(project, 'master').and_return(true)
          allow(ProtectedBranch).to receive(:protected?).with(project, 'feature').and_return(true)
        end

        it 'raises an error if the user is not allowed to do forced pushes to protected branches' do
          expect(Gitlab::Checks::ForcePush).to receive(:force_push?).and_return(true)

          expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to force push code to a protected branch on this project.')
        end

        it 'raises an error if the user is not allowed to merge to protected branches' do
          expect_any_instance_of(Gitlab::Checks::MatchingMergeRequest).to receive(:match?).and_return(true)
          expect(user_access).to receive(:can_merge_to_branch?).and_return(false)
          expect(user_access).to receive(:can_push_to_branch?).and_return(false)

          expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to merge code into protected branches on this project.')
        end

        it 'raises an error if the user is not allowed to push to protected branches' do
          expect(user_access).to receive(:can_push_to_branch?).and_return(false)

          expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to push code to protected branches on this project.')
        end

        context 'branch deletion' do
          let(:newrev) { '0000000000000000000000000000000000000000' }
          let(:ref) { 'refs/heads/feature' }

          context 'if the user is not allowed to delete protected branches' do
            it 'raises an error' do
              expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You are not allowed to delete protected branches from this project. Only a project master or owner can delete a protected branch.')
            end
          end

          context 'if the user is allowed to delete protected branches' do
            before do
              project.add_master(user)
            end

            context 'through the web interface' do
              let(:protocol) { 'web' }

              it 'allows branch deletion' do
                expect { subject }.not_to raise_error
              end
            end

            context 'over SSH or HTTP' do
              it 'raises an error' do
                expect { subject }.to raise_error(Gitlab::GitAccess::UnauthorizedError, 'You can only delete protected branches using the web interface.')
              end
            end
          end
        end
      end
    end
  end
end
