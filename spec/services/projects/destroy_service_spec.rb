require 'spec_helper'

describe Projects::DestroyService do
  let!(:user) { create(:user) }
  let!(:project) { create(:project, :repository, namespace: user.namespace) }
  let!(:path) { project.repository.path_to_repo }
  let!(:remove_path) { path.sub(/\.git\Z/, "+#{project.id}+deleted.git") }
  let!(:async) { false } # execute or async_execute

  before do
    stub_container_registry_config(enabled: true)
    stub_container_registry_tags(repository: :any, tags: [])
  end

  shared_examples 'deleting the project' do
    it 'deletes the project' do
      expect(Project.unscoped.all).not_to include(project)

      expect(project.gitlab_shell.exists?(project.repository_storage_path, path + '.git')).to be_falsey
      expect(project.gitlab_shell.exists?(project.repository_storage_path, remove_path + '.git')).to be_falsey
    end
  end

  shared_examples 'deleting the project with pipeline and build' do
    context 'with pipeline and build' do # which has optimistic locking
      let!(:pipeline) { create(:ci_pipeline, project: project) }
      let!(:build) { create(:ci_build, :artifacts, pipeline: pipeline) }

      before do
        perform_enqueued_jobs do
          destroy_project(project, user, {})
        end
      end

      it_behaves_like 'deleting the project'
    end
  end

  shared_examples 'handles errors thrown during async destroy' do |error_message|
    it 'does not allow the error to bubble up' do
      expect do
        Sidekiq::Testing.inline! { destroy_project(project, user, {}) }
      end.not_to raise_error
    end

    it 'unmarks the project as "pending deletion"' do
      Sidekiq::Testing.inline! { destroy_project(project, user, {}) }

      expect(project.reload.pending_delete).to be(false)
    end

    it 'stores an error message in `projects.delete_error`' do
      Sidekiq::Testing.inline! { destroy_project(project, user, {}) }

      expect(project.reload.delete_error).to be_present
      expect(project.delete_error).to include(error_message)
    end
  end

  context 'Sidekiq inline' do
    before do
      # Run sidekiq immediatly to check that renamed repository will be removed
      Sidekiq::Testing.inline! { destroy_project(project, user, {}) }
    end

    it_behaves_like 'deleting the project'
  end

  context 'Sidekiq fake' do
    before do
      # Dont run sidekiq to check if renamed repository exists
      Sidekiq::Testing.fake! { destroy_project(project, user, {}) }
    end

    it { expect(Project.all).not_to include(project) }
    it { expect(Dir.exist?(path)).to be_falsey }
    it { expect(Dir.exist?(remove_path)).to be_truthy }
  end

  context 'when flushing caches fail' do
    before do
      new_user = create(:user)
      project.team.add_user(new_user, Gitlab::Access::DEVELOPER)
      allow_any_instance_of(described_class).to receive(:flush_caches).and_raise(::Redis::CannotConnectError)
    end

    it 'keeps project team intact upon an error' do
      Sidekiq::Testing.inline! do
        begin
          destroy_project(project, user, {})
        rescue ::Redis::CannotConnectError
        end
      end

      expect(project.team.members.count).to eq 2
    end
  end

  context 'with async_execute' do
    let(:async) { true }

    context 'async delete of project with private issue visibility' do
      before do
        project.project_feature.update_attribute("issues_access_level", ProjectFeature::PRIVATE)
        # Run sidekiq immediately to check that renamed repository will be removed
        Sidekiq::Testing.inline! { destroy_project(project, user, {}) }
      end

      it_behaves_like 'deleting the project'
    end

    it_behaves_like 'deleting the project with pipeline and build'

    context 'errors' do
      context 'when `remove_legacy_registry_tags` fails' do
        before do
          expect_any_instance_of(described_class)
            .to receive(:remove_legacy_registry_tags).and_return(false)
        end

        it_behaves_like 'handles errors thrown during async destroy', "Failed to remove some tags"
      end

      context 'when `remove_repository` fails' do
        before do
          expect_any_instance_of(described_class)
            .to receive(:remove_repository).and_return(false)
        end

        it_behaves_like 'handles errors thrown during async destroy', "Failed to remove project repository"
      end

      context 'when `execute` raises expected error' do
        before do
          expect_any_instance_of(Project)
            .to receive(:destroy!).and_raise(StandardError.new("Other error message"))
        end

        it_behaves_like 'handles errors thrown during async destroy', "Other error message"
      end

      context 'when `execute` raises unexpected error' do
        before do
          expect_any_instance_of(Project)
            .to receive(:destroy!).and_raise(Exception.new('Other error message'))
        end

        it 'allows error to bubble up and rolls back project deletion' do
          expect do
            Sidekiq::Testing.inline! { destroy_project(project, user, {}) }
          end.to raise_error(Exception, 'Other error message')

          expect(project.reload.pending_delete).to be(false)
          expect(project.delete_error).to include("Other error message")
        end
      end
    end
  end

  describe 'container registry' do
    context 'when there are regular container repositories' do
      let(:container_repository) { create(:container_repository) }

      before do
        stub_container_registry_tags(repository: project.full_path + '/image',
                                     tags: ['tag'])
        project.container_repositories << container_repository
      end

      context 'when image repository deletion succeeds' do
        it 'removes tags' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(true)

          destroy_project(project, user)
        end
      end

      context 'when image repository deletion fails' do
        it 'raises an exception' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(false)

          expect(destroy_project(project, user)).to be false
        end
      end
    end

    context 'when there are tags for legacy root repository' do
      before do
        stub_container_registry_tags(repository: project.full_path,
                                     tags: ['tag'])
      end

      context 'when image repository tags deletion succeeds' do
        it 'removes tags' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(true)

          destroy_project(project, user)
        end
      end

      context 'when image repository tags deletion fails' do
        it 'raises an exception' do
          expect_any_instance_of(ContainerRepository)
            .to receive(:delete_tags!).and_return(false)

          expect(destroy_project(project, user)).to be false
        end
      end
    end
  end

  def destroy_project(project, user, params = {})
    if async
      Projects::DestroyService.new(project, user, params).async_execute
    else
      Projects::DestroyService.new(project, user, params).execute
    end
  end
end
