require 'spec_helper'

describe GroupDestroyWorker do
  let(:group) { create(:group) }
  let(:user) { create(:admin) }
  let!(:project) { create(:empty_project, namespace: group) }

  subject { GroupDestroyWorker.new }

  describe "#perform" do
    it "deletes the project" do
      subject.perform(group.id, user.id)

      expect(Group.all).not_to include(group)
      expect(Project.all).not_to include(project)
      expect(Dir.exist?(project.path)).to be_falsey
    end
  end
end
