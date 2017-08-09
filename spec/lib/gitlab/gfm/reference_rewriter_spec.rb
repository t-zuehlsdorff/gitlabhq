require 'spec_helper'

describe Gitlab::Gfm::ReferenceRewriter do
  let(:text) { 'some text' }
  let(:old_project) { create(:project, name: 'old-project') }
  let(:new_project) { create(:project, name: 'new-project') }
  let(:user) { create(:user) }

  before do
    old_project.team << [user, :reporter]
  end

  describe '#rewrite' do
    subject do
      described_class.new(text, old_project, user).rewrite(new_project)
    end

    context 'multiple issues and merge requests referenced' do
      let!(:issue_first) { create(:issue, project: old_project) }
      let!(:issue_second) { create(:issue, project: old_project) }
      let!(:merge_request) { create(:merge_request, source_project: old_project) }

      context 'plain text description' do
        let(:text) { 'Description that references #1, #2 and !1' }

        it { is_expected.to include issue_first.to_reference(new_project) }
        it { is_expected.to include issue_second.to_reference(new_project) }
        it { is_expected.to include merge_request.to_reference(new_project) }
      end

      context 'description with ignored elements' do
        let(:text) do
          "Hi. This references #1, but not `#2`\n" +
            '<pre>and not !1</pre>'
        end

        it { is_expected.to include issue_first.to_reference(new_project) }
        it { is_expected.not_to include issue_second.to_reference(new_project) }
        it { is_expected.not_to include merge_request.to_reference(new_project) }
      end

      context 'description ambigous elements' do
        context 'url' do
          let(:url) { 'http://gitlab.com/#1' }
          let(:text) { "This references #1, but not #{url}" }

          it { is_expected.to include url }
        end

        context 'code' do
          let(:text) { "#1, but not `[#1]`" }
          it { is_expected.to eq "#{issue_first.to_reference(new_project)}, but not `[#1]`" }
        end

        context 'code reverse' do
          let(:text) { "not `#1`, but #1" }
          it { is_expected.to eq "not `#1`, but #{issue_first.to_reference(new_project)}" }
        end

        context 'code in random order' do
          let(:text) { "#1, `#1`, #1, `#1`" }
          let(:ref) { issue_first.to_reference(new_project) }

          it { is_expected.to eq "#{ref}, `#1`, #{ref}, `#1`" }
        end

        context 'description with project labels' do
          let!(:label) { create(:label, id: 123, name: 'test', project: old_project) }
          let(:project_ref) { old_project.to_reference(new_project) }

          context 'label referenced by id' do
            let(:text) { '#1 and ~123' }
            it { is_expected.to eq %Q{#{project_ref}#1 and #{project_ref}~123} }
          end

          context 'label referenced by text' do
            let(:text) { '#1 and ~"test"' }
            it { is_expected.to eq %Q{#{project_ref}#1 and #{project_ref}~123} }
          end
        end

        context 'description with group labels' do
          let(:old_group) { create(:group) }
          let!(:group_label) { create(:group_label, id: 321, name: 'group label', group: old_group) }
          let(:project_ref) { old_project.to_reference(new_project) }

          before do
            old_project.update(namespace: old_group)
          end

          context 'label referenced by id' do
            let(:text) { '#1 and ~321' }
            it { is_expected.to eq %Q{#{project_ref}#1 and #{project_ref}~321} }
          end

          context 'label referenced by text' do
            let(:text) { '#1 and ~"group label"' }
            it { is_expected.to eq %Q{#{project_ref}#1 and #{project_ref}~321} }
          end
        end
      end

      context 'reference contains milestone' do
        let(:milestone) { create(:milestone) }
        let(:text) { "milestone ref: #{milestone.to_reference}" }

        it { is_expected.to eq text }
      end
    end
  end
end
