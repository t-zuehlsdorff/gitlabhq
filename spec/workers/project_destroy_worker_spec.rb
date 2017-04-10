require 'spec_helper'

describe ProjectDestroyWorker do
  let(:project) { create(:project, :repository) }
  let(:path) { project.repository.path_to_repo }

  subject { ProjectDestroyWorker.new }

  describe "#perform" do
    it "deletes the project" do
      subject.perform(project.id, project.owner.id, {})

      expect(Project.all).not_to include(project)
      expect(Dir.exist?(path)).to be_falsey
    end

    it "deletes the project but skips repo deletion" do
      subject.perform(project.id, project.owner.id, { "skip_repo" => true })

      expect(Project.all).not_to include(project)
      expect(Dir.exist?(path)).to be_truthy
    end
  end
end
