require 'spec_helper'

feature 'Runners' do
  given(:user) { create(:user) }

  background do
    sign_in(user)
  end

  context 'when a project has enabled shared_runners' do
    given(:project) { create(:project) }

    background do
      project.add_master(user)
    end

    context 'when a specific runner is activated on the project' do
      given(:specific_runner) { create(:ci_runner, :specific) }

      background do
        project.runners << specific_runner
      end

      scenario 'user sees the specific runner' do
        visit runners_path(project)

        within '.activated-specific-runners' do
          expect(page).to have_content(specific_runner.display_name)
        end

        click_on specific_runner.short_sha

        expect(page).to have_content(specific_runner.platform)
      end

      scenario 'user removes an activated specific runner if this is last project for that runners' do
        visit runners_path(project)

        within '.activated-specific-runners' do
          click_on 'Remove Runner'
        end

        expect(page).not_to have_content(specific_runner.display_name)
      end

      context 'when a runner has a tag' do
        background do
          specific_runner.update(tag_list: ['tag'])
        end

        scenario 'user edits runner not to run untagged jobs' do
          visit runners_path(project)

          within '.activated-specific-runners' do
            first('.edit-runner > a').click
          end

          expect(page.find_field('runner[run_untagged]')).to be_checked

          uncheck 'runner_run_untagged'
          click_button 'Save changes'

          expect(page).to have_content 'Can run untagged jobs No'
        end
      end

      context 'when a shared runner is activated on the project' do
        given!(:shared_runner) { create(:ci_runner, :shared) }

        scenario 'user sees CI/CD setting page' do
          visit runners_path(project)

          expect(page.find('.available-shared-runners')).to have_content(shared_runner.display_name)
        end
      end
    end

    context 'when a specific runner exists in another project' do
      given(:another_project) { create(:project) }
      given(:specific_runner) { create(:ci_runner, :specific) }

      background do
        another_project.add_master(user)
        another_project.runners << specific_runner
      end

      scenario 'user enables and disables a specific runner' do
        visit runners_path(project)

        within '.available-specific-runners' do
          click_on 'Enable for this project'
        end

        expect(page.find('.activated-specific-runners')).to have_content(specific_runner.display_name)

        within '.activated-specific-runners' do
          click_on 'Disable for this project'
        end

        expect(page.find('.available-specific-runners')).to have_content(specific_runner.display_name)
      end
    end

    context 'when application settings have shared_runners_text' do
      given(:shared_runners_text) { 'custom **shared** runners description' }
      given(:shared_runners_html) { 'custom shared runners description' }

      background do
        stub_application_setting(shared_runners_text: shared_runners_text)
      end

      scenario 'user sees shared runners description' do
        visit runners_path(project)

        expect(page.find('.shared-runners-description')).to have_content(shared_runners_html)
      end
    end
  end

  context 'when a project has disabled shared_runners' do
    given(:project) { create(:project, shared_runners_enabled: false) }

    background do
      project.add_master(user)
    end

    scenario 'user enables shared runners' do
      visit runners_path(project)

      click_on 'Enable shared Runners'

      expect(page.find('.shared-runners-description')).to have_content('Disable shared Runners')
    end
  end
end
