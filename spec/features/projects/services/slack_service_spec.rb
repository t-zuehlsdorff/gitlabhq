require 'spec_helper'

feature 'Projects > Slack service > Setup events' do
  let(:user) { create(:user) }
  let(:service) { SlackService.new }
  let(:project) { create(:project, slack_service: service) }

  background do
    service.fields
    service.update_attributes(push_channel: 1, issue_channel: 2, merge_request_channel: 3, note_channel: 4, tag_push_channel: 5, pipeline_channel: 6, wiki_page_channel: 7)
    project.team << [user, :master]
    sign_in(user)
  end

  scenario 'user can filter events by channel' do
    visit edit_project_service_path(project, service)

    expect(page.find_field("service_push_channel").value).to have_content '1'
    expect(page.find_field("service_issue_channel").value).to have_content '2'
    expect(page.find_field("service_merge_request_channel").value).to have_content '3'
    expect(page.find_field("service_note_channel").value).to have_content '4'
    expect(page.find_field("service_tag_push_channel").value).to have_content '5'
    expect(page.find_field("service_pipeline_channel").value).to have_content '6'
    expect(page.find_field("service_wiki_page_channel").value).to have_content '7'
  end
end
