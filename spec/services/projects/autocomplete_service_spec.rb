require 'spec_helper'

describe Projects::AutocompleteService do
  describe '#issues' do
    describe 'confidential issues' do
      let(:author) { create(:user) }
      let(:assignee) { create(:user) }
      let(:non_member) { create(:user) }
      let(:member) { create(:user) }
      let(:admin) { create(:admin) }
      let(:project) { create(:project, :public) }
      let!(:issue) { create(:issue, project: project, title: 'Issue 1') }
      let!(:security_issue_1) { create(:issue, :confidential, project: project, title: 'Security issue 1', author: author) }
      let!(:security_issue_2) { create(:issue, :confidential, title: 'Security issue 2', project: project, assignees: [assignee]) }

      it 'does not list project confidential issues for guests' do
        autocomplete = described_class.new(project, nil)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).not_to include security_issue_1.iid
        expect(issues).not_to include security_issue_2.iid
        expect(issues.count).to eq 1
      end

      it 'does not list project confidential issues for non project members' do
        autocomplete = described_class.new(project, non_member)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).not_to include security_issue_1.iid
        expect(issues).not_to include security_issue_2.iid
        expect(issues.count).to eq 1
      end

      it 'does not list project confidential issues for project members with guest role' do
        project.team << [member, :guest]

        autocomplete = described_class.new(project, non_member)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).not_to include security_issue_1.iid
        expect(issues).not_to include security_issue_2.iid
        expect(issues.count).to eq 1
      end

      it 'lists project confidential issues for author' do
        autocomplete = described_class.new(project, author)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).to include security_issue_1.iid
        expect(issues).not_to include security_issue_2.iid
        expect(issues.count).to eq 2
      end

      it 'lists project confidential issues for assignee' do
        autocomplete = described_class.new(project, assignee)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).not_to include security_issue_1.iid
        expect(issues).to include security_issue_2.iid
        expect(issues.count).to eq 2
      end

      it 'lists project confidential issues for project members' do
        project.team << [member, :developer]

        autocomplete = described_class.new(project, member)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).to include security_issue_1.iid
        expect(issues).to include security_issue_2.iid
        expect(issues.count).to eq 3
      end

      it 'lists all project issues for admin' do
        autocomplete = described_class.new(project, admin)
        issues = autocomplete.issues.map(&:iid)

        expect(issues).to include issue.iid
        expect(issues).to include security_issue_1.iid
        expect(issues).to include security_issue_2.iid
        expect(issues.count).to eq 3
      end
    end
  end

  describe '#milestones' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:project) { create(:project, group: group) }
    let!(:group_milestone) { create(:milestone, group: group) }
    let!(:project_milestone) { create(:milestone, project: project) }

    let(:milestone_titles) { described_class.new(project, user).milestones.map(&:title) }

    it 'includes project and group milestones' do
      expect(milestone_titles).to eq([group_milestone.title, project_milestone.title])
    end

    it 'does not include closed milestones' do
      group_milestone.close

      expect(milestone_titles).to eq([project_milestone.title])
    end

    it 'does not include milestones from other projects in the group' do
      other_project = create(:project, group: group)
      project_milestone.update!(project: other_project)

      expect(milestone_titles).to eq([group_milestone.title])
    end
  end
end
