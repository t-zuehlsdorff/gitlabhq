require 'spec_helper'

describe Gitlab::GitalyClient::Notifications do
  describe '#post_receive' do
    let(:project) { create(:empty_project) }
    let(:storage_name) { project.repository_storage }
    let(:relative_path) { project.path_with_namespace + '.git' }
    subject { described_class.new(project.repository) }

    it 'sends a post_receive message' do
      expect_any_instance_of(Gitaly::Notifications::Stub).
        to receive(:post_receive).with(gitaly_request_with_path(storage_name, relative_path))

      subject.post_receive
    end
  end
end
