require 'rails_helper'

feature 'Issues > User uses quick actions', feature: true, js: true do
  include QuickActionsHelpers

  it_behaves_like 'issuable record that supports quick actions in its description and notes', :issue do
    let(:issuable) { create(:issue, project: project) }
  end

  describe 'issue-only commands' do
    let(:user) { create(:user) }
    let(:project) { create(:project, :public) }

    before do
      project.team << [user, :master]
      sign_in(user)
      visit project_issue_path(project, issue)
    end

    after do
      wait_for_requests
    end

    describe 'adding a due date from note' do
      let(:issue) { create(:issue, project: project) }

      context 'when the current user can update the due date' do
        it 'does not create a note, and sets the due date accordingly' do
          write_note("/due 2016-08-28")

          expect(page).not_to have_content '/due 2016-08-28'
          expect(page).to have_content 'Commands applied'

          issue.reload

          expect(issue.due_date).to eq Date.new(2016, 8, 28)
        end
      end

      context 'when the current user cannot update the due date' do
        let(:guest) { create(:user) }
        before do
          project.team << [guest, :guest]
          gitlab_sign_out
          sign_in(guest)
          visit project_issue_path(project, issue)
        end

        it 'does not create a note, and sets the due date accordingly' do
          write_note("/due 2016-08-28")

          expect(page).to have_content '/due 2016-08-28'
          expect(page).not_to have_content 'Commands applied'

          issue.reload

          expect(issue.due_date).to be_nil
        end
      end
    end

    describe 'removing a due date from note' do
      let(:issue) { create(:issue, project: project, due_date: Date.new(2016, 8, 28)) }

      context 'when the current user can update the due date' do
        it 'does not create a note, and removes the due date accordingly' do
          expect(issue.due_date).to eq Date.new(2016, 8, 28)

          write_note("/remove_due_date")

          expect(page).not_to have_content '/remove_due_date'
          expect(page).to have_content 'Commands applied'

          issue.reload

          expect(issue.due_date).to be_nil
        end
      end

      context 'when the current user cannot update the due date' do
        let(:guest) { create(:user) }
        before do
          project.team << [guest, :guest]
          gitlab_sign_out
          sign_in(guest)
          visit project_issue_path(project, issue)
        end

        it 'does not create a note, and sets the due date accordingly' do
          write_note("/remove_due_date")

          expect(page).to have_content '/remove_due_date'
          expect(page).not_to have_content 'Commands applied'

          issue.reload

          expect(issue.due_date).to eq Date.new(2016, 8, 28)
        end
      end
    end

    describe 'Issuable time tracking' do
      let(:issue) { create(:issue, project: project) }

      before do
        project.team << [user, :developer]
      end

      context 'Issue' do
        before do
          visit project_issue_path(project, issue)
        end

        it_behaves_like 'issuable time tracker'
      end

      context 'Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        before do
          visit project_merge_request_path(project, merge_request)
        end

        it_behaves_like 'issuable time tracker'
      end
    end

    describe 'toggling the WIP prefix from the title from note' do
      let(:issue) { create(:issue, project: project) }

      it 'does not recognize the command nor create a note' do
        write_note("/wip")

        expect(page).not_to have_content '/wip'
      end
    end
  end
end
