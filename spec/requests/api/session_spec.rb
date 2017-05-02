require 'spec_helper'

describe API::Session do
  let(:user) { create(:user) }

  describe "POST /session" do
    context "when valid password" do
      it "returns private token" do
        post api("/session"), email: user.email, password: '12345678'
        expect(response).to have_http_status(201)

        expect(json_response['email']).to eq(user.email)
        expect(json_response['private_token']).to eq(user.private_token)
        expect(json_response['is_admin']).to eq(user.admin?)
        expect(json_response['can_create_project']).to eq(user.can_create_project?)
        expect(json_response['can_create_group']).to eq(user.can_create_group?)
      end

      context 'with 2FA enabled' do
        it 'rejects sign in attempts' do
          user = create(:user, :two_factor)

          post api('/session'), email: user.email, password: user.password

          expect(response).to have_http_status(401)
          expect(response.body).to include('You have 2FA enabled.')
        end
      end
    end

    context 'when email has case-typo and password is valid' do
      it 'returns private token' do
        post api('/session'), email: user.email.upcase, password: '12345678'
        expect(response.status).to eq 201

        expect(json_response['email']).to eq user.email
        expect(json_response['private_token']).to eq user.private_token
        expect(json_response['is_admin']).to eq user.admin?
        expect(json_response['can_create_project']).to eq user.can_create_project?
        expect(json_response['can_create_group']).to eq user.can_create_group?
      end
    end

    context 'when login has case-typo and password is valid' do
      it 'returns private token' do
        post api('/session'), login: user.username.upcase, password: '12345678'
        expect(response.status).to eq 201

        expect(json_response['email']).to eq user.email
        expect(json_response['private_token']).to eq user.private_token
        expect(json_response['is_admin']).to eq user.admin?
        expect(json_response['can_create_project']).to eq user.can_create_project?
        expect(json_response['can_create_group']).to eq user.can_create_group?
      end
    end

    context "when invalid password" do
      it "returns authentication error" do
        post api("/session"), email: user.email, password: '123'
        expect(response).to have_http_status(401)

        expect(json_response['email']).to be_nil
        expect(json_response['private_token']).to be_nil
      end
    end

    context "when empty password" do
      it "returns authentication error with email" do
        post api("/session"), email: user.email

        expect(response).to have_http_status(400)
      end

      it "returns authentication error with username" do
        post api("/session"), email: user.username

        expect(response).to have_http_status(400)
      end
    end

    context "when empty name" do
      it "returns authentication error" do
        post api("/session"), password: user.password

        expect(response).to have_http_status(400)
      end
    end

    context "when user is blocked" do
      it "returns authentication error" do
        user.block
        post api("/session"), email: user.username, password: user.password

        expect(response).to have_http_status(401)
      end
    end

    context "when user is ldap_blocked" do
      it "returns authentication error" do
        user.ldap_block
        post api("/session"), email: user.username, password: user.password

        expect(response).to have_http_status(401)
      end
    end
  end
end
