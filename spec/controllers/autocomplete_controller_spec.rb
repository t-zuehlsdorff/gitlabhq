require 'spec_helper'

describe AutocompleteController do
  let(:project) { create(:project) }
  let(:user) { project.owner }

  context 'GET users' do
    let!(:user2) { create(:user) }
    let!(:non_member) { create(:user) }

    context 'project members' do
      before do
        sign_in(user)
      end

      describe 'GET #users with project ID' do
        before do
          get(:users, project_id: project.id)
        end

        it 'returns the project members' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq(1)
          expect(json_response.map { |u| u["username"] }).to include(user.username)
        end
      end

      describe 'GET #users with unknown project' do
        before do
          get(:users, project_id: 'unknown')
        end

        it { expect(response).to have_http_status(404) }
      end
    end

    context 'group members' do
      let(:group) { create(:group) }

      before do
        group.add_owner(user)
        sign_in(user)
      end

      describe 'GET #users with group ID' do
        before do
          get(:users, group_id: group.id)
        end

        it 'returns the group members' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq(1)
          expect(json_response.first["username"]).to eq user.username
        end
      end

      describe 'GET #users with unknown group ID' do
        before do
          get(:users, group_id: 'unknown')
        end

        it { expect(response).to have_http_status(404) }
      end
    end

    context 'non-member login for public project' do
      let(:project) { create(:project, :public) }

      before do
        sign_in(non_member)
      end

      describe 'GET #users with project ID' do
        before do
          get(:users, project_id: project.id, current_user: true)
        end

        it 'returns the project members and non-members' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq(2)
          expect(json_response.map { |u| u['username'] }).to include(user.username, non_member.username)
        end
      end
    end

    context 'all users' do
      before do
        sign_in(user)
        get(:users)
      end

      it { expect(json_response).to be_kind_of(Array) }
      it { expect(json_response.size).to eq User.count }
    end

    context 'user order' do
      it 'shows exact matches first' do
        reported_user = create(:user, username: 'reported_user', name: 'Doug')
        user = create(:user, username: 'user', name: 'User')
        user1 = create(:user, username: 'user1', name: 'Ian')

        sign_in(user)
        get(:users, search: 'user')

        response_usernames = json_response.map { |user| user['username']  }

        expect(response_usernames.take(3)).to match_array([user.username, reported_user.username, user1.username])
      end
    end

    context 'limited users per page' do
      let(:per_page) { 2 }

      before do
        sign_in(user)
        get(:users, per_page: per_page)
      end

      it { expect(json_response).to be_kind_of(Array) }
      it { expect(json_response.size).to eq(per_page) }
    end

    context 'unauthenticated user' do
      let(:public_project) { create(:project, :public) }

      describe 'GET #users with public project' do
        before do
          public_project.add_guest(user)
          get(:users, project_id: public_project.id)
        end

        it { expect(json_response).to be_kind_of(Array) }
        it { expect(json_response.size).to eq 2 }
      end

      describe 'GET #users with project' do
        before do
          get(:users, project_id: project.id)
        end

        it { expect(response).to have_http_status(404) }
      end

      describe 'GET #users with unknown project' do
        before do
          get(:users, project_id: 'unknown')
        end

        it { expect(response).to have_http_status(404) }
      end

      describe 'GET #users with inaccessible group' do
        before do
          project.add_guest(user)
          get(:users, group_id: user.namespace.id)
        end

        it { expect(response).to have_http_status(404) }
      end

      describe 'GET #users with no project' do
        before do
          get(:users)
        end

        it { expect(json_response).to be_kind_of(Array) }
        it { expect(json_response).to be_empty }
      end

      describe 'GET #users with todo filter' do
        it 'gives an array of users' do
          get :users, todo_filter: true

          expect(response.status).to eq 200
          expect(json_response).to be_kind_of(Array)
        end
      end
    end

    context 'author of issuable included' do
      context 'authenticated' do
        before do
          sign_in(user)
        end

        it 'includes the author' do
          get(:users, author_id: non_member.id)

          expect(json_response.first["username"]).to eq non_member.username
        end

        it 'rejects non existent user ids' do
          get(:users, author_id: 99999)

          expect(json_response.collect { |u| u['id'] }).not_to include(99999)
        end
      end

      context 'without authenticating' do
        it 'returns empty result' do
          get(:users, author_id: non_member.id)

          expect(json_response).to be_empty
        end
      end
    end

    context 'skip_users parameter included' do
      before do
        sign_in(user)
      end

      it 'skips the user IDs passed' do
        get(:users, skip_users: [user, user2].map(&:id))

        response_user_ids = json_response.map { |user| user['id'] }

        expect(response_user_ids).to contain_exactly(non_member.id)
      end
    end
  end

  context 'GET projects' do
    let(:authorized_project) { create(:project) }
    let(:authorized_search_project) { create(:project, name: 'rugged') }

    before do
      sign_in(user)
      project.add_master(user)
    end

    context 'authorized projects' do
      before do
        authorized_project.add_master(user)
      end

      describe 'GET #projects with project ID' do
        before do
          get(:projects, project_id: project.id)
        end

        it 'returns projects' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq(2)

          expect(json_response.first['id']).to eq(0)
          expect(json_response.first['name_with_namespace']).to eq 'No project'

          expect(json_response.last['id']).to eq authorized_project.id
          expect(json_response.last['name_with_namespace']).to eq authorized_project.name_with_namespace
        end
      end
    end

    context 'authorized projects and search' do
      before do
        authorized_project.add_master(user)
        authorized_search_project.add_master(user)
      end

      describe 'GET #projects with project ID and search' do
        before do
          get(:projects, project_id: project.id, search: 'rugged')
        end

        it 'returns projects' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq(2)

          expect(json_response.last['id']).to eq authorized_search_project.id
          expect(json_response.last['name_with_namespace']).to eq authorized_search_project.name_with_namespace
        end
      end
    end

    context 'authorized projects apply limit' do
      before do
        authorized_project2 = create(:project)
        authorized_project3 = create(:project)

        authorized_project.add_master(user)
        authorized_project2.add_master(user)
        authorized_project3.add_master(user)

        stub_const 'MoveToProjectFinder::PAGE_SIZE', 2
      end

      describe 'GET #projects with project ID' do
        before do
          get(:projects, project_id: project.id)
        end

        it 'returns projects' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq 3 # Of a total of 4
        end
      end
    end

    context 'authorized projects with offset' do
      before do
        authorized_project2 = create(:project)
        authorized_project3 = create(:project)

        authorized_project.add_master(user)
        authorized_project2.add_master(user)
        authorized_project3.add_master(user)
      end

      describe 'GET #projects with project ID and offset_id' do
        before do
          get(:projects, project_id: project.id, offset_id: authorized_project.id)
        end

        it 'returns "No project"' do
          expect(json_response.detect { |item| item['id'] == 0 }).to be_nil # 'No project' is not there
          expect(json_response.detect { |item| item['id'] == authorized_project.id }).to be_nil # Offset project is not there either
        end
      end
    end

    context 'authorized projects without admin_issue ability' do
      before do
        authorized_project.add_guest(user)

        expect(user.can?(:admin_issue, authorized_project)).to eq(false)
      end

      describe 'GET #projects with project ID' do
        before do
          get(:projects, project_id: project.id)
        end

        it 'returns a single "No project"' do
          expect(json_response).to be_kind_of(Array)
          expect(json_response.size).to eq(1) # 'No project'
          expect(json_response.first['id']).to eq 0
        end
      end
    end
  end
end
