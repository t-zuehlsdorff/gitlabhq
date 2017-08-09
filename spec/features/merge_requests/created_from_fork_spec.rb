require 'spec_helper'

feature 'Merge request created from fork' do
  given(:user) { create(:user) }
  given(:project) { create(:project, :public, :repository) }
  given(:fork_project) { create(:project, :public, :repository) }

  given!(:merge_request) do
    create(:forked_project_link, forked_to_project: fork_project,
                                 forked_from_project: project)

    create(:merge_request_with_diffs, source_project: fork_project,
                                      target_project: project,
                                      description: 'Test merge request')
  end

  background do
    fork_project.team << [user, :master]
    sign_in user
  end

  scenario 'user can access merge request' do
    visit_merge_request(merge_request)

    expect(page).to have_content 'Test merge request'
  end

  context 'when a commit comment exists on the merge request' do
    given(:comment) { 'A commit comment' }
    given(:reply) { 'A reply comment' }

    background do
      create(:note_on_commit, note: comment,
                              project: fork_project,
                              commit_id: merge_request.commit_shas.first)
    end

    scenario 'user can reply to the comment', js: true do
      visit_merge_request(merge_request)

      expect(page).to have_content(comment)

      page.within('.discussion-notes') do
        find('.btn-text-field').click
        find('#note_note').send_keys(reply)
        find('.comment-btn').click
      end

      wait_for_requests

      expect(page).to have_content(reply)
    end
  end

  context 'source project is deleted' do
    background do
      MergeRequests::MergeService.new(project, user).execute(merge_request)
      fork_project.destroy!
    end

    scenario 'user can access merge request', js: true do
      visit_merge_request(merge_request)

      expect(page).to have_content 'Test merge request'
      expect(page).to have_content "(removed):#{merge_request.source_branch}"
    end
  end

  context 'pipeline present in source project' do
    given(:pipeline) do
      create(:ci_pipeline,
             project: fork_project,
             sha: merge_request.diff_head_sha,
             ref: merge_request.source_branch)
    end

    background do
      create(:ci_build, pipeline: pipeline, name: 'rspec')
      create(:ci_build, pipeline: pipeline, name: 'spinach')
    end

    scenario 'user visits a pipelines page', js: true do
      visit_merge_request(merge_request)
      page.within('.merge-request-tabs') { click_link 'Pipelines' }

      page.within('.ci-table') do
        expect(page).to have_content pipeline.status
        expect(page).to have_content pipeline.id
      end
    end
  end

  def visit_merge_request(mr)
    visit project_merge_request_path(project, mr)
  end
end
