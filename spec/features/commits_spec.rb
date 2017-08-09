require 'spec_helper'

describe 'Commits' do
  include CiStatusHelper

  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }

  describe 'CI' do
    before do
      sign_in(user)
      stub_ci_pipeline_to_return_yaml_file
    end

    let(:creator) { create(:user) }

    let!(:pipeline) do
      create(:ci_pipeline,
             project: project,
             user: creator,
             ref: project.default_branch,
             sha: project.commit.sha,
             status: :success,
             created_at: 5.months.ago)
    end

    context 'commit status is Generic Commit Status' do
      let!(:status) { create(:generic_commit_status, pipeline: pipeline) }

      before do
        project.team << [user, :reporter]
      end

      describe 'Commit builds' do
        before do
          visit ci_status_path(pipeline)
        end

        it { expect(page).to have_content pipeline.sha[0..7] }

        it 'contains generic commit status build' do
          page.within('.table-holder') do
            expect(page).to have_content "##{status.id}" # build id
            expect(page).to have_content 'generic'       # build name
          end
        end
      end
    end

    context 'commit status is Ci Build' do
      let!(:build) { create(:ci_build, pipeline: pipeline) }
      let(:artifacts_file) { fixture_file_upload(Rails.root + 'spec/fixtures/banana_sample.gif', 'image/gif') }

      context 'when logged as developer' do
        before do
          project.team << [user, :developer]
        end

        describe 'Project commits' do
          let!(:pipeline_from_other_branch) do
            create(:ci_pipeline,
                   project: project,
                   ref: 'fix',
                   sha: project.commit.sha,
                   status: :failed)
          end

          before do
            visit project_commits_path(project, :master)
          end

          it 'shows correct build status from default branch' do
            page.within("//li[@id='commit-#{pipeline.short_sha}']") do
              expect(page).to have_css('.ci-status-link')
              expect(page).to have_css('.ci-status-icon-success')
            end
          end
        end

        describe 'Commit builds', :js do
          before do
            visit ci_status_path(pipeline)
          end

          it 'shows pipeline`s data' do
            expect(page).to have_content pipeline.sha[0..7]
            expect(page).to have_content pipeline.git_commit_message
            expect(page).to have_content pipeline.user.name
          end
        end

        context 'Download artifacts' do
          before do
            build.update_attributes(artifacts_file: artifacts_file)
          end

          it do
            visit ci_status_path(pipeline)
            click_on 'Download artifacts'
            expect(page.response_headers['Content-Type']).to eq(artifacts_file.content_type)
          end
        end

        describe 'Cancel all builds' do
          it 'cancels commit', :js do
            visit ci_status_path(pipeline)
            click_on 'Cancel running'
            expect(page).to have_content 'canceled'
          end
        end

        describe 'Cancel build' do
          it 'cancels build', :js do
            visit ci_status_path(pipeline)
            find('.js-btn-cancel-pipeline').click
            expect(page).to have_content 'canceled'
          end
        end

        describe '.gitlab-ci.yml not found warning' do
          context 'ci builds enabled' do
            it "does not show warning" do
              visit ci_status_path(pipeline)
              expect(page).not_to have_content '.gitlab-ci.yml not found in this commit'
            end

            it 'shows warning' do
              stub_ci_pipeline_yaml_file(nil)
              visit ci_status_path(pipeline)
              expect(page).to have_content '.gitlab-ci.yml not found in this commit'
            end
          end

          context 'ci builds disabled' do
            before do
              stub_ci_builds_disabled
              stub_ci_pipeline_yaml_file(nil)
              visit ci_status_path(pipeline)
            end

            it 'does not show warning' do
              expect(page).not_to have_content '.gitlab-ci.yml not found in this commit'
            end
          end
        end
      end

      context "when logged as reporter" do
        before do
          project.team << [user, :reporter]
          build.update_attributes(artifacts_file: artifacts_file)
          visit ci_status_path(pipeline)
        end

        it 'Renders header', :js do
          expect(page).to have_content pipeline.sha[0..7]
          expect(page).to have_content pipeline.git_commit_message
          expect(page).to have_content pipeline.user.name
          expect(page).not_to have_link('Cancel running')
          expect(page).not_to have_link('Retry')
        end

        it do
          expect(page).to have_link('Download artifacts')
        end
      end

      context 'when accessing internal project with disallowed access', :js do
        before do
          project.update(
            visibility_level: Gitlab::VisibilityLevel::INTERNAL,
            public_builds: false)
          build.update_attributes(artifacts_file: artifacts_file)
          visit ci_status_path(pipeline)
        end

        it do
          expect(page).to have_content pipeline.sha[0..7]
          expect(page).to have_content pipeline.git_commit_message
          expect(page).to have_content pipeline.user.name

          expect(page).not_to have_link('Cancel running')
          expect(page).not_to have_link('Retry')
        end
      end
    end
  end

  context 'viewing commits for a branch' do
    let(:branch_name) { 'master' }

    before do
      project.team << [user, :master]
      sign_in(user)
      visit project_commits_path(project, branch_name)
    end

    it 'includes the committed_date for each commit' do
      commits = project.repository.commits(branch_name)

      commits.each do |commit|
        expect(page).to have_content("committed #{commit.committed_date.strftime("%b %d, %Y")}")
      end
    end
  end

  describe 'GPG signed commits', :js do
    it 'changes from unverified to verified when the user changes his email to match the gpg key' do
      user = create :user, email: 'unrelated.user@example.org'
      project.team << [user, :master]

      Sidekiq::Testing.inline! do
        create :gpg_key, key: GpgHelpers::User1.public_key, user: user
      end

      sign_in(user)

      visit project_commits_path(project, :'signed-commits')

      within '#commits-list' do
        expect(page).to have_content 'Unverified'
        expect(page).not_to have_content 'Verified'
      end

      # user changes his email which makes the gpg key verified
      Sidekiq::Testing.inline! do
        user.skip_reconfirmation!
        user.update_attributes!(email: GpgHelpers::User1.emails.first)
      end

      visit project_commits_path(project, :'signed-commits')

      within '#commits-list' do
        expect(page).to have_content 'Unverified'
        expect(page).to have_content 'Verified'
      end
    end

    it 'changes from unverified to verified when the user adds the missing gpg key' do
      user = create :user, email: GpgHelpers::User1.emails.first
      project.team << [user, :master]

      sign_in(user)

      visit project_commits_path(project, :'signed-commits')

      within '#commits-list' do
        expect(page).to have_content 'Unverified'
        expect(page).not_to have_content 'Verified'
      end

      # user adds the gpg key which makes the signature valid
      Sidekiq::Testing.inline! do
        create :gpg_key, key: GpgHelpers::User1.public_key, user: user
      end

      visit project_commits_path(project, :'signed-commits')

      within '#commits-list' do
        expect(page).to have_content 'Unverified'
        expect(page).to have_content 'Verified'
      end
    end

    it 'shows popover badges' do
      gpg_user = create :user, email: GpgHelpers::User1.emails.first, username: 'nannie.bernhard', name: 'Nannie Bernhard'
      Sidekiq::Testing.inline! do
        create :gpg_key, key: GpgHelpers::User1.public_key, user: gpg_user
      end

      user = create :user
      project.team << [user, :master]

      sign_in(user)
      visit project_commits_path(project, :'signed-commits')

      # unverified signature
      click_on 'Unverified', match: :first
      within '.popover' do
        expect(page).to have_content 'This commit was signed with an unverified signature.'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User2.primary_keyid}"
      end

      # verified and the gpg user has a gitlab profile
      click_on 'Verified', match: :first
      within '.popover' do
        expect(page).to have_content 'This commit was signed with a verified signature.'
        expect(page).to have_content 'Nannie Bernhard'
        expect(page).to have_content '@nannie.bernhard'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User1.primary_keyid}"
      end

      # verified and the gpg user's profile doesn't exist anymore
      gpg_user.destroy!

      visit project_commits_path(project, :'signed-commits')

      click_on 'Verified', match: :first
      within '.popover' do
        expect(page).to have_content 'This commit was signed with a verified signature.'
        expect(page).to have_content 'Nannie Bernhard'
        expect(page).to have_content 'nannie.bernhard@example.com'
        expect(page).to have_content "GPG Key ID: #{GpgHelpers::User1.primary_keyid}"
      end
    end
  end
end
