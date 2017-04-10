require 'spec_helper'

describe TestHookService, services: true do
  let(:user)    { create(:user) }
  let(:project) { create(:project, :repository) }
  let(:hook)    { create(:project_hook, project: project) }

  describe '#execute' do
    it "executes successfully" do
      stub_request(:post, hook.url).to_return(status: 200)
      expect(TestHookService.new.execute(hook, user)).to be_truthy
    end
  end
end
