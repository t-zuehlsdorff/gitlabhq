require 'spec_helper'

shared_examples 'discussion comments' do |resource_name|
  let(:form_selector) { '.js-main-target-form' }
  let(:dropdown_selector) { "#{form_selector} .comment-type-dropdown" }
  let(:toggle_selector) { "#{dropdown_selector} .dropdown-toggle" }
  let(:menu_selector) { "#{dropdown_selector} .dropdown-menu" }
  let(:submit_selector) { "#{form_selector} .js-comment-submit-button" }
  let(:close_selector) { "#{form_selector} .btn-comment-and-close" }
  let(:comments_selector) { '.timeline > .note.timeline-entry' }

  it 'should show a comment type toggle' do
    expect(page).to have_selector toggle_selector
  end

  it 'clicking "Comment" will post a comment' do
    find("#{form_selector} .note-textarea").send_keys('a')

    find(submit_selector).click

    find(comments_selector, match: :first)
    new_comment = all(comments_selector).last

    expect(new_comment).to have_content 'a'
    expect(new_comment).not_to have_selector '.discussion'
  end

  if resource_name == 'issue'
    it "clicking 'Comment & close #{resource_name}' will post a comment and close the #{resource_name}" do
      find("#{form_selector} .note-textarea").send_keys('a')

      find(close_selector).click

      find(comments_selector, match: :first)
      find("#{comments_selector}.system-note")
      entries = all(comments_selector)
      close_note = entries.last
      new_comment = entries[-2]

      expect(close_note).to have_content 'closed'
      expect(new_comment).not_to have_selector '.discussion'
    end
  end

  describe 'when the toggle is clicked' do
    before do
      find("#{form_selector} .note-textarea").send_keys('a')

      find(toggle_selector).click
    end

    it 'opens a comment type dropdown with "Comment" and "Start discussion"' do
      expect(page).to have_selector menu_selector
    end

    it 'has a "Comment" item' do
      menu = find(menu_selector)

      expect(menu).to have_content 'Comment'
      expect(menu).to have_content "Add a general comment to this #{resource_name}."
    end

    it 'has a "Start discussion" item' do
      menu = find(menu_selector)

      expect(menu).to have_content 'Start discussion'
      expect(menu).to have_content "Discuss a specific suggestion or question#{' that needs to be resolved' if resource_name == 'merge request'}."
    end

    it 'has the "Comment" item selected by default' do
      find("#{menu_selector} li", match: :first)
      items = all("#{menu_selector} li")

      expect(items.first).to have_content 'Comment'
      expect(items.first).to have_selector '.fa-check'
      expect(items.first['class']).to match 'droplab-item-selected'

      expect(items.last).to have_content 'Start discussion'
      expect(items.last).not_to have_selector '.fa-check'
      expect(items.last['class']).not_to match 'droplab-item-selected'
    end

    it 'closes the menu when clicking the toggle' do
      find(toggle_selector).click

      expect(page).not_to have_selector menu_selector
    end

    it 'closes the menu when clicking the body' do
      find('body').click

      expect(page).not_to have_selector menu_selector
    end

    it 'clicking the ul padding should not change the text' do
      find(menu_selector).trigger 'click'

      expect(find(dropdown_selector)).to have_content 'Comment'
    end

    describe 'when selecting "Start discussion"' do
      before do
        find("#{menu_selector} li", match: :first)
        all("#{menu_selector} li").last.click
      end

      it 'updates the note_type input to "DiscussionNote"' do
        expect(find("#{form_selector} #note_type", visible: false).value).to eq('DiscussionNote')
      end

      it 'updates the submit button text' do
        expect(find(dropdown_selector)).to have_content 'Start discussion'
      end

      if resource_name =~ /(issue|merge request)/
        it 'updates the close button text' do
          expect(find(close_selector)).to have_content "Start discussion & close #{resource_name}"
        end

        it 'typing does not change the close button text' do
          find("#{form_selector} .note-textarea").send_keys('b')

          expect(find(close_selector)).to have_content "Start discussion & close #{resource_name}"
        end
      end

      it 'closes the dropdown' do
        expect(page).not_to have_selector menu_selector
      end

      it 'clicking "Start discussion" will post a discussion' do
        find(submit_selector).click

        find(comments_selector, match: :first)
        new_comment = all(comments_selector).last

        expect(new_comment).to have_content 'a'
        expect(new_comment).to have_selector '.discussion'
      end

      if resource_name == 'issue'
        it "clicking 'Start discussion & close #{resource_name}' will post a discussion and close the #{resource_name}" do
          find(close_selector).click

          find(comments_selector, match: :first)
          find("#{comments_selector}.system-note")
          entries = all(comments_selector)
          close_note = entries.last
          new_discussion = entries[-2]

          expect(close_note).to have_content 'closed'
          expect(new_discussion).to have_selector '.discussion'
        end
      end

      describe 'when opening the menu' do
        before do
          find(toggle_selector).click
        end

        it 'should have "Start discussion" selected' do
          find("#{menu_selector} li", match: :first)
          items = all("#{menu_selector} li")

          expect(items.first).to have_content 'Comment'
          expect(items.first).not_to have_selector '.fa-check'
          expect(items.first['class']).not_to match 'droplab-item-selected'

          expect(items.last).to have_content 'Start discussion'
          expect(items.last).to have_selector '.fa-check'
          expect(items.last['class']).to match 'droplab-item-selected'
        end

        describe 'when selecting "Comment"' do
          before do
            find("#{menu_selector} li", match: :first).click
          end

          it 'clears the note_type input"' do
            expect(find("#{form_selector} #note_type", visible: false).value).to eq('')
          end

          it 'updates the submit button text' do
            expect(find(dropdown_selector)).to have_content 'Comment'
          end

          if resource_name =~ /(issue|merge request)/
            it 'updates the close button text' do
              expect(find(close_selector)).to have_content "Comment & close #{resource_name}"
            end

            it 'typing does not change the close button text' do
              find("#{form_selector} .note-textarea").send_keys('b')

              expect(find(close_selector)).to have_content "Comment & close #{resource_name}"
            end
          end

          it 'closes the dropdown' do
            expect(page).not_to have_selector menu_selector
          end

          it 'should have "Comment" selected when opening the menu' do
            find(toggle_selector).click

            find("#{menu_selector} li", match: :first)
            items = all("#{menu_selector} li")

            expect(items.first).to have_content 'Comment'
            expect(items.first).to have_selector '.fa-check'
            expect(items.first['class']).to match 'droplab-item-selected'

            expect(items.last).to have_content 'Start discussion'
            expect(items.last).not_to have_selector '.fa-check'
            expect(items.last['class']).not_to match 'droplab-item-selected'
          end
        end
      end
    end
  end

  if resource_name =~ /(issue|merge request)/
    describe "on a closed #{resource_name}" do
      before do
        find("#{form_selector} .js-note-target-close").click

        find("#{form_selector} .note-textarea").send_keys('a')
      end

      it "should show a 'Comment & reopen #{resource_name}' button" do
        expect(find("#{form_selector} .js-note-target-reopen")).to have_content "Comment & reopen #{resource_name}"
      end

      it "should show a 'Start discussion & reopen #{resource_name}' button when 'Start discussion' is selected" do
        find(toggle_selector).click

        find("#{menu_selector} li", match: :first)
        all("#{menu_selector} li").last.click

        expect(find("#{form_selector} .js-note-target-reopen")).to have_content "Start discussion & reopen #{resource_name}"
      end
    end
  end
end

describe 'Discussion Comments', :feature, :js do
  include RepoHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project) }

  before do
    project.team << [user, :developer]

    login_as(user)
  end

  describe 'on a merge request' do
    let(:merge_request) { create(:merge_request, source_project: project) }

    before do
      visit namespace_project_merge_request_path(project.namespace, project, merge_request)
    end

    it_behaves_like 'discussion comments', 'merge request'
  end

  describe 'on an issue' do
    let(:issue) { create(:issue, project: project) }

    before do
      visit namespace_project_issue_path(project.namespace, project, issue)
    end

    it_behaves_like 'discussion comments', 'issue'
  end

  describe 'on an snippet' do
    let(:snippet) { create(:project_snippet, :private, project: project, author: user) }

    before do
      visit namespace_project_snippet_path(project.namespace, project, snippet)
    end

    it_behaves_like 'discussion comments', 'snippet'
  end

  describe 'on a commit' do
    before do
      visit namespace_project_commit_path(project.namespace, project, sample_commit.id)
    end

    it_behaves_like 'discussion comments', 'commit'
  end
end
