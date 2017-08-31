# encoding: utf-8

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20170523083112_migrate_old_artifacts.rb')

describe MigrateOldArtifacts do
  let(:migration) { described_class.new }
  let!(:directory) { Dir.mktmpdir }

  before do
    allow(Gitlab.config.artifacts).to receive(:path).and_return(directory)
  end

  after do
    FileUtils.remove_entry_secure(directory)
  end

  context 'with migratable data' do
    let(:project1) { create(:project, ci_id: 2) }
    let(:project2) { create(:project, ci_id: 3) }
    let(:project3) { create(:project) }

    let(:pipeline1) { create(:ci_empty_pipeline, project: project1) }
    let(:pipeline2) { create(:ci_empty_pipeline, project: project2) }
    let(:pipeline3) { create(:ci_empty_pipeline, project: project3) }

    let!(:build_with_legacy_artifacts) { create(:ci_build, pipeline: pipeline1) }
    let!(:build_without_artifacts) { create(:ci_build, pipeline: pipeline1) }
    let!(:build2) { create(:ci_build, :artifacts, pipeline: pipeline2) }
    let!(:build3) { create(:ci_build, :artifacts, pipeline: pipeline3) }

    before do
      store_artifacts_in_legacy_path(build_with_legacy_artifacts)
    end

    it "legacy artifacts are not accessible" do
      expect(build_with_legacy_artifacts.artifacts?).to be_falsey
    end

    it "legacy artifacts are set" do
      expect(build_with_legacy_artifacts.artifacts_file_identifier).not_to be_nil
    end

    describe '#min_id' do
      subject { migration.send(:min_id) }

      it 'returns the newest build for which ci_id is not defined' do
        is_expected.to eq(build3.id)
      end
    end

    describe '#builds_with_artifacts' do
      subject { migration.send(:builds_with_artifacts).map(&:id) }

      it 'returns a list of builds that has artifacts and could be migrated' do
        is_expected.to contain_exactly(build_with_legacy_artifacts.id, build2.id)
      end
    end

    describe '#up' do
      context 'when migrating artifacts' do
        before do
          migration.up
        end

        it 'all files do have artifacts' do
          Ci::Build.with_artifacts do |build|
            expect(build).to have_artifacts
          end
        end

        it 'artifacts are no longer present on legacy path' do
          expect(File.exist?(legacy_path(build_with_legacy_artifacts))).to eq(false)
        end
      end

      context 'when there are aritfacts in old and new directory' do
        before do
          store_artifacts_in_legacy_path(build2)

          migration.up
        end

        it 'does not move old files' do
          expect(File.exist?(legacy_path(build2))).to eq(true)
        end
      end
    end

    private

    def store_artifacts_in_legacy_path(build)
      FileUtils.mkdir_p(legacy_path(build))

      FileUtils.copy(
        Rails.root.join('spec/fixtures/ci_build_artifacts.zip'),
        File.join(legacy_path(build), "ci_build_artifacts.zip"))

      FileUtils.copy(
        Rails.root.join('spec/fixtures/ci_build_artifacts_metadata.gz'),
        File.join(legacy_path(build), "ci_build_artifacts_metadata.gz"))

      build.update_columns(
        artifacts_file: 'ci_build_artifacts.zip',
        artifacts_metadata: 'ci_build_artifacts_metadata.gz')

      build.reload
    end

    def legacy_path(build)
      File.join(directory,
        build.created_at.utc.strftime('%Y_%m'),
        build.project.ci_id.to_s,
        build.id.to_s)
    end
  end
end
