require 'spec_helper'

describe Banzai::ReferenceParser::IssueParser do
  include ReferenceParserHelpers

  let(:project) { create(:project, :public) }
  let(:user)    { create(:user) }
  let(:issue)   { create(:issue, project: project) }
  let(:link)    { empty_html_link }
  subject       { described_class.new(project, user) }

  describe '#nodes_visible_to_user' do
    context 'when the link has a data-issue attribute' do
      before do
        link['data-issue'] = issue.id.to_s
      end

      it_behaves_like "referenced feature visibility", "issues"

      it 'returns the nodes when the user can read the issue' do
        expect(Ability).to receive(:issues_readable_by_user)
          .with([issue], user)
          .and_return([issue])

        expect(subject.nodes_visible_to_user(user, [link])).to eq([link])
      end

      it 'returns an empty Array when the user can not read the issue' do
        expect(Ability).to receive(:issues_readable_by_user)
          .with([issue], user)
          .and_return([])

        expect(subject.nodes_visible_to_user(user, [link])).to eq([])
      end
    end

    context 'when the link does not have a data-issue attribute' do
      it 'returns an empty Array' do
        expect(subject.nodes_visible_to_user(user, [link])).to eq([])
      end
    end
  end

  describe '#referenced_by' do
    context 'when the link has a data-issue attribute' do
      context 'using an existing issue ID' do
        before do
          link['data-issue'] = issue.id.to_s
        end

        it 'returns an Array of issues' do
          expect(subject.referenced_by([link])).to eq([issue])
        end

        it 'returns an empty Array when the list of nodes is empty' do
          expect(subject.referenced_by([link])).to eq([issue])
          expect(subject.referenced_by([])).to eq([])
        end
      end

      context 'when issue with given ID does not exist' do
        before do
          link['data-issue'] = '-1'
        end

        it 'returns an empty Array' do
          expect(subject.referenced_by([link])).to eq([])
        end
      end
    end
  end

  describe '#issues_for_nodes' do
    it 'returns a Hash containing the issues for a list of nodes' do
      link['data-issue'] = issue.id.to_s
      nodes = [link]

      expect(subject.issues_for_nodes(nodes)).to eq({ link => issue })
    end
  end
end
