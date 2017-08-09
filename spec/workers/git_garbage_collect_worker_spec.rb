require 'fileutils'

require 'spec_helper'

describe GitGarbageCollectWorker do
  let(:project) { create(:project, :repository) }
  let(:shell) { Gitlab::Shell.new }

  subject { described_class.new }

  describe "#perform" do
    shared_examples 'flushing ref caches' do |gitaly|
      it "flushes ref caches when the task if 'gc'" do
        expect(subject).to receive(:command).with(:gc).and_return([:the, :command])

        if gitaly
          expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:garbage_collect)
            .and_return(nil)
        else
          expect(Gitlab::Popen).to receive(:popen)
            .with([:the, :command], project.repository.path_to_repo).and_return(["", 0])
        end

        expect_any_instance_of(Repository).to receive(:after_create_branch).and_call_original
        expect_any_instance_of(Repository).to receive(:branch_names).and_call_original
        expect_any_instance_of(Repository).to receive(:branch_count).and_call_original
        expect_any_instance_of(Repository).to receive(:has_visible_content?).and_call_original

        subject.perform(project.id)
      end
    end

    context "with Gitaly turned on" do
      it_should_behave_like 'flushing ref caches', true
    end

    context "with Gitaly turned off", skip_gitaly_mock: true do
      it_should_behave_like 'flushing ref caches', false
    end

    context "repack_full" do
      it "calls Gitaly" do
        expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:repack_full)
          .and_return(nil)

        subject.perform(project.id, :full_repack)
      end
    end

    context "repack_incremental" do
      it "calls Gitaly" do
        expect_any_instance_of(Gitlab::GitalyClient::RepositoryService).to receive(:repack_incremental)
          .and_return(nil)

        subject.perform(project.id, :incremental_repack)
      end
    end

    shared_examples 'gc tasks' do
      before do
        allow(subject).to receive(:bitmaps_enabled?).and_return(bitmaps_enabled)
      end

      it 'incremental repack adds a new packfile' do
        create_objects(project)
        before_packs = packs(project)

        expect(before_packs.count).to be >= 1

        subject.perform(project.id, 'incremental_repack')
        after_packs = packs(project)

        # Exactly one new pack should have been created
        expect(after_packs.count).to eq(before_packs.count + 1)

        # Previously existing packs are still around
        expect(before_packs & after_packs).to eq(before_packs)
      end

      it 'full repack consolidates into 1 packfile' do
        create_objects(project)
        subject.perform(project.id, 'incremental_repack')
        before_packs = packs(project)

        expect(before_packs.count).to be >= 2

        subject.perform(project.id, 'full_repack')
        after_packs = packs(project)

        expect(after_packs.count).to eq(1)

        # Previously existing packs should be gone now
        expect(after_packs - before_packs).to eq(after_packs)

        expect(File.exist?(bitmap_path(after_packs.first))).to eq(bitmaps_enabled)
      end

      it 'gc consolidates into 1 packfile and updates packed-refs' do
        create_objects(project)
        before_packs = packs(project)
        before_packed_refs = packed_refs(project)

        expect(before_packs.count).to be >= 1

        subject.perform(project.id, 'gc')
        after_packed_refs = packed_refs(project)
        after_packs = packs(project)

        expect(after_packs.count).to eq(1)

        # Previously existing packs should be gone now
        expect(after_packs - before_packs).to eq(after_packs)

        # The packed-refs file should have been updated during 'git gc'
        expect(before_packed_refs).not_to eq(after_packed_refs)

        expect(File.exist?(bitmap_path(after_packs.first))).to eq(bitmaps_enabled)
      end
    end

    context 'with bitmaps enabled' do
      let(:bitmaps_enabled) { true }

      include_examples 'gc tasks'
    end

    context 'with bitmaps disabled' do
      let(:bitmaps_enabled) { false }

      include_examples 'gc tasks'
    end
  end

  # Create a new commit on a random new branch
  def create_objects(project)
    rugged = project.repository.rugged
    old_commit = rugged.branches.first.target
    new_commit_sha = Rugged::Commit.create(
      rugged,
      message: "hello world #{SecureRandom.hex(6)}",
      author: Gitlab::Git.committer_hash(email: 'foo@bar', name: 'baz'),
      committer: Gitlab::Git.committer_hash(email: 'foo@bar', name: 'baz'),
      tree: old_commit.tree,
      parents: [old_commit]
    )
    GitOperationService.new(nil, project.repository).send(
      :update_ref,
      "refs/heads/#{SecureRandom.hex(6)}",
      new_commit_sha,
      Gitlab::Git::BLANK_SHA
    )
  end

  def packs(project)
    Dir["#{project.repository.path_to_repo}/objects/pack/*.pack"]
  end

  def packed_refs(project)
    path = "#{project.repository.path_to_repo}/packed-refs"
    FileUtils.touch(path)
    File.read(path)
  end

  def bitmap_path(pack)
    pack.sub(/\.pack\z/, '.bitmap')
  end
end
