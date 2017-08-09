require 'spec_helper'

describe Ci::CreatePipelineService do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:admin) }
  let(:ref_name) { 'refs/heads/master' }

  before do
    stub_ci_pipeline_to_return_yaml_file
  end

  describe '#execute' do
    def execute_service(
      source: :push,
      after: project.commit.id,
      message: 'Message',
      ref: ref_name,
      trigger_request: nil)
      params = { ref: ref,
                 before: '00000000',
                 after: after,
                 commits: [{ message: message }] }

      described_class.new(project, user, params).execute(
        source, trigger_request: trigger_request)
    end

    context 'valid params' do
      let(:pipeline) { execute_service }

      let(:pipeline_on_previous_commit) do
        execute_service(
          after: previous_commit_sha_from_ref('master')
        )
      end

      it 'creates a pipeline' do
        expect(pipeline).to be_kind_of(Ci::Pipeline)
        expect(pipeline).to be_valid
        expect(pipeline).to be_persisted
        expect(pipeline).to be_push
        expect(pipeline).to eq(project.pipelines.last)
        expect(pipeline).to have_attributes(user: user)
        expect(pipeline).to have_attributes(status: 'pending')
        expect(pipeline.builds.first).to be_kind_of(Ci::Build)
      end

      it 'increments the prometheus counter' do
        expect(Gitlab::Metrics).to receive(:counter)
          .with(:pipelines_created_total, "Counter of pipelines created")
          .and_call_original

        pipeline
      end

      context 'when merge requests already exist for this source branch' do
        it 'updates head pipeline of each merge request' do
          merge_request_1 = create(:merge_request, source_branch: 'master', target_branch: "branch_1", source_project: project)
          merge_request_2 = create(:merge_request, source_branch: 'master', target_branch: "branch_2", source_project: project)

          head_pipeline = pipeline

          expect(merge_request_1.reload.head_pipeline).to eq(head_pipeline)
          expect(merge_request_2.reload.head_pipeline).to eq(head_pipeline)
        end

        context 'when there is no pipeline for source branch' do
          it "does not update merge request head pipeline" do
            merge_request = create(:merge_request, source_branch: 'other_branch', target_branch: "branch_1", source_project: project)

            head_pipeline = pipeline

            expect(merge_request.reload.head_pipeline).not_to eq(head_pipeline)
          end
        end

        context 'when merge request target project is different from source project' do
          let!(:target_project) { create(:project, :repository) }
          let!(:forked_project_link) { create(:forked_project_link, forked_to_project: project, forked_from_project: target_project) }

          it 'updates head pipeline for merge request' do
            merge_request =
              create(:merge_request, source_branch: 'master', target_branch: "branch_1", source_project: project, target_project: target_project)

            head_pipeline = pipeline

            expect(merge_request.reload.head_pipeline).to eq(head_pipeline)
          end
        end

        context 'when the pipeline is not the latest for the branch' do
          it 'does not update merge request head pipeline' do
            merge_request = create(:merge_request, source_branch: 'master', target_branch: "branch_1", source_project: project)

            allow_any_instance_of(Ci::Pipeline).to receive(:latest?).and_return(false)

            pipeline

            expect(merge_request.reload.head_pipeline).to be_nil
          end
        end
      end

      context 'auto-cancel enabled' do
        before do
          project.update(auto_cancel_pending_pipelines: 'enabled')
        end

        it 'does not cancel HEAD pipeline' do
          pipeline
          pipeline_on_previous_commit

          expect(pipeline.reload).to have_attributes(status: 'pending', auto_canceled_by_id: nil)
        end

        it 'auto cancel pending non-HEAD pipelines' do
          pipeline_on_previous_commit
          pipeline

          expect(pipeline_on_previous_commit.reload).to have_attributes(status: 'canceled', auto_canceled_by_id: pipeline.id)
        end

        it 'does not cancel running outdated pipelines' do
          pipeline_on_previous_commit.run
          execute_service

          expect(pipeline_on_previous_commit.reload).to have_attributes(status: 'running', auto_canceled_by_id: nil)
        end

        it 'cancel created outdated pipelines' do
          pipeline_on_previous_commit.update(status: 'created')
          pipeline

          expect(pipeline_on_previous_commit.reload).to have_attributes(status: 'canceled', auto_canceled_by_id: pipeline.id)
        end

        it 'does not cancel pipelines from the other branches' do
          pending_pipeline = execute_service(
            ref: 'refs/heads/feature',
            after: previous_commit_sha_from_ref('feature')
          )
          pipeline

          expect(pending_pipeline.reload).to have_attributes(status: 'pending', auto_canceled_by_id: nil)
        end
      end

      context 'auto-cancel disabled' do
        before do
          project.update(auto_cancel_pending_pipelines: 'disabled')
        end

        it 'does not auto cancel pending non-HEAD pipelines' do
          pipeline_on_previous_commit
          pipeline

          expect(pipeline_on_previous_commit.reload)
            .to have_attributes(status: 'pending', auto_canceled_by_id: nil)
        end
      end

      def previous_commit_sha_from_ref(ref)
        project.commit(ref).parent.sha
      end
    end

    context "skip tag if there is no build for it" do
      it "creates commit if there is appropriate job" do
        expect(execute_service).to be_persisted
      end

      it "creates commit if there is no appropriate job but deploy job has right ref setting" do
        config = YAML.dump({ deploy: { script: "ls", only: ["master"] } })
        stub_ci_pipeline_yaml_file(config)

        expect(execute_service).to be_persisted
      end
    end

    it 'skips creating pipeline for refs without .gitlab-ci.yml' do
      stub_ci_pipeline_yaml_file(nil)

      expect(execute_service).not_to be_persisted
      expect(Ci::Pipeline.count).to eq(0)
    end

    shared_examples 'a failed pipeline' do
      it 'creates failed pipeline' do
        stub_ci_pipeline_yaml_file(ci_yaml)

        pipeline = execute_service(message: message)

        expect(pipeline).to be_persisted
        expect(pipeline.builds.any?).to be false
        expect(pipeline.status).to eq('failed')
        expect(pipeline.yaml_errors).not_to be_nil
      end
    end

    context 'when yaml is invalid' do
      let(:ci_yaml) { 'invalid: file: fiile' }
      let(:message) { 'Message' }

      it_behaves_like 'a failed pipeline'

      context 'when receive git commit' do
        before do
          allow_any_instance_of(Ci::Pipeline).to receive(:git_commit_message) { message }
        end

        it_behaves_like 'a failed pipeline'
      end
    end

    context 'when commit contains a [ci skip] directive' do
      let(:message) { "some message[ci skip]" }

      ci_messages = [
        "some message[ci skip]",
        "some message[skip ci]",
        "some message[CI SKIP]",
        "some message[SKIP CI]",
        "some message[ci_skip]",
        "some message[skip_ci]",
        "some message[ci-skip]",
        "some message[skip-ci]"
      ]

      before do
        allow_any_instance_of(Ci::Pipeline).to receive(:git_commit_message) { message }
      end

      ci_messages.each do |ci_message|
        it "skips builds creation if the commit message is #{ci_message}" do
          pipeline = execute_service(message: ci_message)

          expect(pipeline).to be_persisted
          expect(pipeline.builds.any?).to be false
          expect(pipeline.status).to eq("skipped")
        end
      end

      shared_examples 'creating a pipeline' do
        it 'does not skip pipeline creation' do
          allow_any_instance_of(Ci::Pipeline).to receive(:git_commit_message) { commit_message }

          pipeline = execute_service(message: commit_message)

          expect(pipeline).to be_persisted
          expect(pipeline.builds.first.name).to eq("rspec")
        end
      end

      context 'when commit message does not contain [ci skip] nor [skip ci]' do
        let(:commit_message) { 'some message' }

        it_behaves_like 'creating a pipeline'
      end

      context 'when commit message is nil' do
        let(:commit_message) { nil }

        it_behaves_like 'creating a pipeline'
      end

      context 'when there is [ci skip] tag in commit message and yaml is invalid' do
        let(:ci_yaml) { 'invalid: file: fiile' }

        it_behaves_like 'a failed pipeline'
      end
    end

    context 'when there are no jobs for this pipeline' do
      before do
        config = YAML.dump({ test: { script: 'ls', only: ['feature'] } })
        stub_ci_pipeline_yaml_file(config)
      end

      it 'does not create a new pipeline' do
        result = execute_service

        expect(result).not_to be_persisted
        expect(Ci::Build.all).to be_empty
        expect(Ci::Pipeline.count).to eq(0)
      end
    end

    context 'with manual actions' do
      before do
        config = YAML.dump({ deploy: { script: 'ls', when: 'manual' } })
        stub_ci_pipeline_yaml_file(config)
      end

      it 'does not create a new pipeline' do
        result = execute_service

        expect(result).to be_persisted
        expect(result.manual_actions).not_to be_empty
      end
    end

    context 'with environment' do
      before do
        config = YAML.dump(deploy: { environment: { name: "review/$CI_COMMIT_REF_NAME" }, script: 'ls' })
        stub_ci_pipeline_yaml_file(config)
      end

      it 'creates the environment' do
        result = execute_service

        expect(result).to be_persisted
        expect(Environment.find_by(name: "review/master")).not_to be_nil
      end
    end

    context 'when environment with invalid name' do
      before do
        config = YAML.dump(deploy: { environment: { name: 'name,with,commas' }, script: 'ls' })
        stub_ci_pipeline_yaml_file(config)
      end

      it 'does not create an environment' do
        expect do
          result = execute_service

          expect(result).to be_persisted
        end.not_to change { Environment.count }
      end
    end

    context 'when builds with auto-retries are configured' do
      before do
        config = YAML.dump(rspec: { script: 'rspec', retry: 2 })
        stub_ci_pipeline_yaml_file(config)
      end

      it 'correctly creates builds with auto-retry value configured' do
        pipeline = execute_service

        expect(pipeline).to be_persisted
        expect(pipeline.builds.find_by(name: 'rspec').retries_max).to eq 2
      end
    end

    shared_examples 'when ref is protected' do
      let(:user) { create(:user) }

      context 'when user is developer' do
        before do
          project.add_developer(user)
        end

        it 'does not create a pipeline' do
          expect(execute_service).not_to be_persisted
          expect(Ci::Pipeline.count).to eq(0)
        end
      end

      context 'when user is master' do
        before do
          project.add_master(user)
        end

        it 'creates a pipeline' do
          expect(execute_service).to be_persisted
          expect(Ci::Pipeline.count).to eq(1)
        end
      end

      context 'when trigger belongs to no one' do
        let(:user) {}
        let(:trigger_request) { create(:ci_trigger_request) }

        it 'does not create a pipeline' do
          expect(execute_service(trigger_request: trigger_request))
            .not_to be_persisted
          expect(Ci::Pipeline.count).to eq(0)
        end
      end

      context 'when trigger belongs to a developer' do
        let(:user) {}

        let(:trigger_request) do
          create(:ci_trigger_request).tap do |request|
            user = create(:user)
            project.add_developer(user)
            request.trigger.update(owner: user)
          end
        end

        it 'does not create a pipeline' do
          expect(execute_service(trigger_request: trigger_request))
            .not_to be_persisted
          expect(Ci::Pipeline.count).to eq(0)
        end
      end

      context 'when trigger belongs to a master' do
        let(:user) {}

        let(:trigger_request) do
          create(:ci_trigger_request).tap do |request|
            user = create(:user)
            project.add_master(user)
            request.trigger.update(owner: user)
          end
        end

        it 'does not create a pipeline' do
          expect(execute_service(trigger_request: trigger_request))
            .to be_persisted
          expect(Ci::Pipeline.count).to eq(1)
        end
      end
    end

    context 'when ref is a protected branch' do
      before do
        create(:protected_branch, project: project, name: 'master')
      end

      it_behaves_like 'when ref is protected'
    end

    context 'when ref is a protected tag' do
      let(:ref_name) { 'refs/tags/v1.0.0' }

      before do
        create(:protected_tag, project: project, name: '*')
      end

      it_behaves_like 'when ref is protected'
    end

    context 'when ref is not protected' do
      context 'when trigger belongs to no one' do
        let(:user) {}
        let(:trigger_request) { create(:ci_trigger_request) }

        it 'creates a pipeline' do
          expect(execute_service(trigger_request: trigger_request))
            .to be_persisted
          expect(Ci::Pipeline.count).to eq(1)
        end
      end
    end
  end

  describe '#allowed_to_create?' do
    let(:user) { create(:user) }
    let(:project) { create(:project, :repository) }
    let(:ref) { 'master' }

    subject do
      described_class.new(project, user, ref: ref)
        .send(:allowed_to_create?, user)
    end

    context 'when user is a developer' do
      before do
        project.add_developer(user)
      end

      it { is_expected.to be_truthy }

      context 'when the branch is protected' do
        let!(:protected_branch) do
          create(:protected_branch, project: project, name: ref)
        end

        it { is_expected.to be_falsey }

        context 'when developers are allowed to merge' do
          let!(:protected_branch) do
            create(:protected_branch,
                   :developers_can_merge,
                   project: project,
                   name: ref)
          end

          it { is_expected.to be_truthy }
        end
      end

      context 'when the tag is protected' do
        let(:ref) { 'v1.0.0' }

        let!(:protected_tag) do
          create(:protected_tag, project: project, name: ref)
        end

        it { is_expected.to be_falsey }

        context 'when developers are allowed to create the tag' do
          let!(:protected_tag) do
            create(:protected_tag,
                   :developers_can_create,
                   project: project,
                   name: ref)
          end

          it { is_expected.to be_truthy }
        end
      end
    end

    context 'when user is a master' do
      before do
        project.add_master(user)
      end

      it { is_expected.to be_truthy }

      context 'when the branch is protected' do
        let!(:protected_branch) do
          create(:protected_branch, project: project, name: ref)
        end

        it { is_expected.to be_truthy }
      end

      context 'when the tag is protected' do
        let(:ref) { 'v1.0.0' }

        let!(:protected_tag) do
          create(:protected_tag, project: project, name: ref)
        end

        it { is_expected.to be_truthy }

        context 'when no one can create the tag' do
          let!(:protected_tag) do
            create(:protected_tag,
                   :no_one_can_create,
                   project: project,
                   name: ref)
          end

          it { is_expected.to be_falsey }
        end
      end
    end

    context 'when owner cannot create pipeline' do
      it { is_expected.to be_falsey }
    end
  end
end
