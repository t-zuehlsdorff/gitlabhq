require 'spec_helper'

describe WikiPages::DestroyService, services: true do
  let(:project) { create(:empty_project) }
  let(:user) { create(:user) }
  let(:page) { create(:wiki_page) }

  subject(:service) { described_class.new(project, user) }

  before do
    project.add_developer(user)
  end

  describe '#execute' do
    it 'executes webhooks' do
      expect(service).to receive(:execute_hooks).once
        .with(instance_of(WikiPage), 'delete')

      service.execute(page)
    end
  end
end
