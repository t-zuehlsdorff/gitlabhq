require('spec_helper')

describe Projects::ProtectedBranchesController do
  describe "GET #index" do
    let(:project) { create(:project_empty_repo, :public) }

    it "redirects empty repo to projects page" do
      get(:index, namespace_id: project.namespace.to_param, project_id: project)
    end
  end
end
