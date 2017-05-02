require 'spec_helper'

describe API::Deployments do
  let(:user)        { create(:user) }
  let(:non_member)  { create(:user) }
  let(:project)     { deployment.environment.project }
  let!(:deployment) { create(:deployment) }

  before do
    project.team << [user, :master]
  end

  describe 'GET /projects/:id/deployments' do
    context 'as member of the project' do
      it 'returns projects deployments' do
        get api("/projects/#{project.id}/deployments", user)

        expect(response).to have_http_status(200)
        expect(response).to include_pagination_headers
        expect(json_response).to be_an Array
        expect(json_response.size).to eq(1)
        expect(json_response.first['iid']).to eq(deployment.iid)
        expect(json_response.first['sha']).to match /\A\h{40}\z/
      end
    end

    context 'as non member' do
      it 'returns a 404 status code' do
        get api("/projects/#{project.id}/deployments", non_member)

        expect(response).to have_http_status(404)
      end
    end
  end

  describe 'GET /projects/:id/deployments/:deployment_id' do
    context 'as a member of the project' do
      it 'returns the projects deployment' do
        get api("/projects/#{project.id}/deployments/#{deployment.id}", user)

        expect(response).to have_http_status(200)
        expect(json_response['sha']).to match /\A\h{40}\z/
        expect(json_response['id']).to eq(deployment.id)
      end
    end

    context 'as non member' do
      it 'returns a 404 status code' do
        get api("/projects/#{project.id}/deployments/#{deployment.id}", non_member)

        expect(response).to have_http_status(404)
      end
    end
  end
end
