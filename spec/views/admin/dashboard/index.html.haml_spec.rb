require 'spec_helper'

describe 'admin/dashboard/index.html.haml' do
  include Devise::Test::ControllerHelpers

  before do
    assign(:projects, create_list(:project, 1))
    assign(:users, create_list(:user, 1))
    assign(:groups, create_list(:group, 1))

    allow(view).to receive(:admin?).and_return(true)
  end

  it "shows version of GitLab Workhorse" do
    render

    expect(rendered).to have_content 'GitLab Workhorse'
    expect(rendered).to have_content Gitlab::Workhorse.version
  end
end
