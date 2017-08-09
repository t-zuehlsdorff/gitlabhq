require 'spec_helper'

describe API::ProtectedBranches do
  let(:user) { create(:user) }
  let!(:project) { create(:project, :repository) }
  let(:protected_name) { 'feature' }
  let(:branch_name) { protected_name }
  let!(:protected_branch) do
    create(:protected_branch, project: project, name: protected_name)
  end

  describe "GET /projects/:id/protected_branches" do
    let(:route) { "/projects/#{project.id}/protected_branches" }

    shared_examples_for 'protected branches' do
      it 'returns the protected branches' do
        get api(route, user), per_page: 100

        expect(response).to have_gitlab_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array

        protected_branch_names = json_response.map { |x| x['name'] }
        expected_branch_names = project.protected_branches.map { |x| x['name'] }
        expect(protected_branch_names).to match_array(expected_branch_names)
      end
    end

    context 'when authenticated as a master' do
      before do
        project.add_master(user)
      end

      it_behaves_like 'protected branches'
    end

    context 'when authenticated as a guest' do
      before do
        project.add_guest(user)
      end

      it_behaves_like '403 response' do
        let(:request) { get api(route, user) }
      end
    end
  end

  describe "GET /projects/:id/protected_branches/:branch" do
    let(:route) { "/projects/#{project.id}/protected_branches/#{branch_name}" }

    shared_examples_for 'protected branch' do
      it 'returns the protected branch' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(200)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(::Gitlab::Access::MASTER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(::Gitlab::Access::MASTER)
      end

      context 'when protected branch does not exist' do
        let(:branch_name) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { get api(route, user) }
          let(:message) { '404 Not found' }
        end
      end
    end

    context 'when authenticated as a master' do
      before do
        project.add_master(user)
      end

      it_behaves_like 'protected branch'

      context 'when protected branch contains a wildcard' do
        let(:protected_name) { 'feature*' }

        it_behaves_like 'protected branch'
      end
    end

    context 'when authenticated as a guest' do
      before do
        project.add_guest(user)
      end

      it_behaves_like '403 response' do
        let(:request) { get api(route, user) }
      end
    end
  end

  describe 'POST /projects/:id/protected_branches' do
    let(:branch_name) { 'new_branch' }

    context 'when authenticated as a master' do 
      before do
        project.add_master(user)
      end

      it 'protects a single branch' do
        post api("/projects/#{project.id}/protected_branches", user), name: branch_name

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
      end

      it 'protects a single branch and developers can push' do
        post api("/projects/#{project.id}/protected_branches", user),
            name: branch_name, push_access_level: 30

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::DEVELOPER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
      end

      it 'protects a single branch and developers can merge' do
        post api("/projects/#{project.id}/protected_branches", user),
            name: branch_name, merge_access_level: 30

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::DEVELOPER)
      end

      it 'protects a single branch and developers can push and merge' do
        post api("/projects/#{project.id}/protected_branches", user),
            name: branch_name, push_access_level: 30, merge_access_level: 30

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::DEVELOPER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::DEVELOPER)
      end

      it 'protects a single branch and no one can push' do
        post api("/projects/#{project.id}/protected_branches", user),
            name: branch_name, push_access_level: 0

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::NO_ACCESS)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
      end

      it 'protects a single branch and no one can merge' do
        post api("/projects/#{project.id}/protected_branches", user),
            name: branch_name, merge_access_level: 0

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::NO_ACCESS)
      end

      it 'protects a single branch and no one can push or merge' do
        post api("/projects/#{project.id}/protected_branches", user),
            name: branch_name, push_access_level: 0, merge_access_level: 0

        expect(response).to have_gitlab_http_status(201)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::NO_ACCESS)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::NO_ACCESS)
      end

      it 'returns a 409 error if the same branch is protected twice' do
        post api("/projects/#{project.id}/protected_branches", user), name: protected_name
        expect(response).to have_gitlab_http_status(409)
      end

      context 'when branch has a wildcard in its name' do
        let(:branch_name) { 'feature/*' }

        it "protects multiple branches with a wildcard in the name" do
          post api("/projects/#{project.id}/protected_branches", user), name: branch_name

          expect(response).to have_gitlab_http_status(201)
          expect(json_response['name']).to eq(branch_name)
          expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
          expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::MASTER)
        end
      end
    end

    context 'when authenticated as a guest' do
      before do
        project.add_guest(user)
      end

      it "returns a 403 error if guest" do
        post api("/projects/#{project.id}/protected_branches/", user), name: branch_name

        expect(response).to have_gitlab_http_status(403)
      end
    end
  end

  describe "DELETE /projects/:id/protected_branches/unprotect/:branch" do
    before do
      project.add_master(user)
    end

    it "unprotects a single branch" do
      delete api("/projects/#{project.id}/protected_branches/#{branch_name}", user)

      expect(response).to have_gitlab_http_status(204)
    end

    it "returns 404 if branch does not exist" do
      delete api("/projects/#{project.id}/protected_branches/barfoo", user)

      expect(response).to have_gitlab_http_status(404)
    end

    context 'when branch has a wildcard in its name' do
      let(:protected_name) { 'feature*' }
      
      it "unprotects a wildcard branch" do
        delete api("/projects/#{project.id}/protected_branches/#{branch_name}", user)

        expect(response).to have_gitlab_http_status(204)
      end
    end
  end
end
