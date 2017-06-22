require 'spec_helper'

feature 'Groups > Members > Last owner cannot leave group', feature: true do
  let(:owner) { create(:user) }
  let(:group) { create(:group) }

  background do
    group.add_owner(owner)
    gitlab_sign_in(owner)
    visit group_path(group)
  end

  scenario 'user does not see a "Leave group" link' do
    expect(page).not_to have_content 'Leave group'
  end
end
