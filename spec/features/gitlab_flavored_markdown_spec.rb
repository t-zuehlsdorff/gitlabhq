require 'spec_helper'

describe "GitLab Flavored Markdown", feature: true do
  let(:project) { create(:empty_project) }
  let(:issue) { create(:issue, project: project) }
  let(:fred) do
    create(:user, name: 'fred') do |user|
      project.add_master(user)
    end
  end

  before do
    login_as(:user)
    project.add_developer(@user)
  end

  describe "for commits" do
    let(:project) { create(:project, :repository) }
    let(:commit) { project.commit }

    before do
      allow_any_instance_of(Commit).to receive(:title).
        and_return("fix #{issue.to_reference}\n\nask #{fred.to_reference} for details")
    end

    it "renders title in commits#index" do
      visit namespace_project_commits_path(project.namespace, project, 'master', limit: 1)

      expect(page).to have_link(issue.to_reference)
    end

    it "renders title in commits#show" do
      visit namespace_project_commit_path(project.namespace, project, commit)

      expect(page).to have_link(issue.to_reference)
    end

    it "renders description in commits#show" do
      visit namespace_project_commit_path(project.namespace, project, commit)

      expect(page).to have_link(fred.to_reference)
    end

    it "renders title in repositories#branches" do
      visit namespace_project_branches_path(project.namespace, project)

      expect(page).to have_link(issue.to_reference)
    end
  end

  describe "for issues", feature: true, js: true do
    before do
      @other_issue = create(:issue,
                            author: @user,
                            assignees: [@user],
                            project: project)
      @issue = create(:issue,
                      author: @user,
                      assignees: [@user],
                      project: project,
                      title: "fix #{@other_issue.to_reference}",
                      description: "ask #{fred.to_reference} for details")

      @note = create(:note_on_issue, noteable: @issue, project: @issue.project, note: "Hello world")
    end

    it "renders subject in issues#index" do
      visit namespace_project_issues_path(project.namespace, project)

      expect(page).to have_link(@other_issue.to_reference)
    end

    it "renders subject in issues#show" do
      visit namespace_project_issue_path(project.namespace, project, @issue)

      expect(page).to have_link(@other_issue.to_reference)
    end

    it "renders details in issues#show" do
      visit namespace_project_issue_path(project.namespace, project, @issue)

      expect(page).to have_link(fred.to_reference)
    end
  end

  describe "for merge requests" do
    let(:project) { create(:project, :repository) }

    before do
      @merge_request = create(:merge_request, source_project: project, target_project: project, title: "fix #{issue.to_reference}")
    end

    it "renders title in merge_requests#index" do
      visit namespace_project_merge_requests_path(project.namespace, project)

      expect(page).to have_link(issue.to_reference)
    end

    it "renders title in merge_requests#show" do
      visit namespace_project_merge_request_path(project.namespace, project, @merge_request)

      expect(page).to have_link(issue.to_reference)
    end
  end

  describe "for milestones" do
    before do
      @milestone = create(:milestone,
                          project: project,
                          title: "fix #{issue.to_reference}",
                          description: "ask #{fred.to_reference} for details")
    end

    it "renders title in milestones#index" do
      visit namespace_project_milestones_path(project.namespace, project)

      expect(page).to have_link(issue.to_reference)
    end

    it "renders title in milestones#show" do
      visit namespace_project_milestone_path(project.namespace, project, @milestone)

      expect(page).to have_link(issue.to_reference)
    end

    it "renders description in milestones#show" do
      visit namespace_project_milestone_path(project.namespace, project, @milestone)

      expect(page).to have_link(fred.to_reference)
    end
  end
end
