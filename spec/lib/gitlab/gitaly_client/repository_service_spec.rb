require 'spec_helper'

describe Gitlab::GitalyClient::RepositoryService do
  let(:project) { create(:project) }
  let(:storage_name) { project.repository_storage }
  let(:relative_path) { project.disk_path + '.git' }
  let(:client) { described_class.new(project.repository) }

  describe '#exists?' do
    it 'sends a repository_exists message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repository_exists)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(exists: true))

      client.exists?
    end
  end

  describe '#garbage_collect' do
    it 'sends a garbage_collect message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:garbage_collect)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:garbage_collect_response))

      client.garbage_collect(true)
    end
  end

  describe '#repack_full' do
    it 'sends a repack_full message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repack_full)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:repack_full_response))

      client.repack_full(true)
    end
  end

  describe '#repack_incremental' do
    it 'sends a repack_incremental message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repack_incremental)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:repack_incremental_response))

      client.repack_incremental
    end
  end

  describe '#repository_size' do
    it 'sends a repository_size message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repository_size)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(size: 0)

      client.repository_size
    end
  end

  describe '#apply_gitattributes' do
    let(:revision) { 'master' }

    it 'sends an apply_gitattributes message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:apply_gitattributes)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:apply_gitattributes_response))

      client.apply_gitattributes(revision)
    end
  end
end
