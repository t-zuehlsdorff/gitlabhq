require 'spec_helper'

describe DiffNote do
  include RepoHelpers

  let(:merge_request) { create(:merge_request) }
  let(:project) { merge_request.project }
  let(:commit) { project.commit(sample_commit.id) }

  let(:path) { "files/ruby/popen.rb" }

  let!(:position) do
    Gitlab::Diff::Position.new(
      old_path: path,
      new_path: path,
      old_line: nil,
      new_line: 14,
      diff_refs: merge_request.diff_refs
    )
  end

  let!(:new_position) do
    Gitlab::Diff::Position.new(
      old_path: path,
      new_path: path,
      old_line: 16,
      new_line: 22,
      diff_refs: merge_request.diff_refs
    )
  end

  subject { create(:diff_note_on_merge_request, project: project, position: position, noteable: merge_request) }

  describe "#position=" do
    context "when provided a string" do
      it "sets the position" do
        subject.position = new_position.to_json

        expect(subject.position).to eq(new_position)
      end
    end

    context "when provided a hash" do
      it "sets the position" do
        subject.position = new_position.to_h

        expect(subject.position).to eq(new_position)
      end
    end

    context "when provided a position object" do
      it "sets the position" do
        subject.position = new_position

        expect(subject.position).to eq(new_position)
      end
    end
  end

  describe "#original_position=" do
    context "when provided a string" do
      it "sets the original position" do
        subject.original_position = new_position.to_json

        expect(subject.original_position).to eq(new_position)
      end
    end

    context "when provided a hash" do
      it "sets the original position" do
        subject.original_position = new_position.to_h

        expect(subject.original_position).to eq(new_position)
      end
    end

    context "when provided a position object" do
      it "sets the original position" do
        subject.original_position = new_position

        expect(subject.original_position).to eq(new_position)
      end
    end
  end

  describe "#diff_file" do
    it "returns the correct diff file" do
      diff_file = subject.diff_file

      expect(diff_file.old_path).to eq(position.old_path)
      expect(diff_file.new_path).to eq(position.new_path)
      expect(diff_file.diff_refs).to eq(position.diff_refs)
    end
  end

  describe "#diff_line" do
    it "returns the correct diff line" do
      diff_line = subject.diff_line

      expect(diff_line.added?).to be true
      expect(diff_line.new_line).to eq(position.new_line)
      expect(diff_line.text).to eq("+    vars = {")
    end
  end

  describe "#line_code" do
    it "returns the correct line code" do
      line_code = Gitlab::Diff::LineCode.generate(position.file_path, position.new_line, 15)

      expect(subject.line_code).to eq(line_code)
    end
  end

  describe "#for_line?" do
    context "when provided the correct diff line" do
      it "returns true" do
        expect(subject.for_line?(subject.diff_line)).to be true
      end
    end

    context "when provided a different diff line" do
      it "returns false" do
        some_line = subject.diff_file.diff_lines.first

        expect(subject.for_line?(some_line)).to be false
      end
    end
  end

  describe "#active?" do
    context "when noteable is a commit" do
      subject { build(:diff_note_on_commit, project: project, position: position) }

      it "returns true" do
        expect(subject.active?).to be true
      end
    end

    context "when noteable is a merge request" do
      context "when the merge request's diff refs match that of the diff note" do
        it "returns true" do
          expect(subject.active?).to be true
        end
      end

      context "when the merge request's diff refs don't match that of the diff note" do
        before do
          allow(subject.noteable).to receive(:diff_refs).and_return(commit.diff_refs)
        end

        it "returns false" do
          expect(subject.active?).to be false
        end
      end
    end
  end

  describe "creation" do
    describe "updating of position" do
      context "when noteable is a commit" do
        let(:diff_note) { create(:diff_note_on_commit, project: project, position: position) }

        it "doesn't update the position" do
          diff_note

          expect(diff_note.original_position).to eq(position)
          expect(diff_note.position).to eq(position)
        end
      end

      context "when noteable is a merge request" do
        let(:diff_note) { create(:diff_note_on_merge_request, project: project, position: position, noteable: merge_request) }

        context "when the note is active" do
          it "doesn't update the position" do
            diff_note

            expect(diff_note.original_position).to eq(position)
            expect(diff_note.position).to eq(position)
          end
        end

        context "when the note is outdated" do
          before do
            allow(merge_request).to receive(:diff_refs).and_return(commit.diff_refs)
          end

          it "updates the position" do
            diff_note

            expect(diff_note.original_position).to eq(position)
            expect(diff_note.position).not_to eq(position)
          end
        end
      end
    end
  end

  describe "#discussion_id" do
    let(:note) { create(:diff_note_on_merge_request) }

    context "when it is newly created" do
      it "has a discussion id" do
        expect(note.discussion_id).not_to be_nil
        expect(note.discussion_id).to match(/\A\h{40}\z/)
      end
    end

    context "when it didn't store a discussion id before" do
      before do
        note.update_column(:discussion_id, nil)
      end

      it "has a discussion id" do
        # The discussion_id is set in `after_initialize`, so `reload` won't work
        reloaded_note = Note.find(note.id)

        expect(reloaded_note.discussion_id).not_to be_nil
        expect(reloaded_note.discussion_id).to match(/\A\h{40}\z/)
      end
    end
  end

  describe '#created_at_diff?' do
    let(:diff_refs) { project.commit(sample_commit.id).diff_refs }
    let(:position) do
      Gitlab::Diff::Position.new(
        old_path: "files/ruby/popen.rb",
        new_path: "files/ruby/popen.rb",
        old_line: nil,
        new_line: 14,
        diff_refs: diff_refs
      )
    end

    context "when noteable is a commit" do
      subject { build(:diff_note_on_commit, project: project, position: position) }

      it "returns true" do
        expect(subject.created_at_diff?(diff_refs)).to be true
      end
    end

    context "when noteable is a merge request" do
      context "when the diff refs match the original one of the diff note" do
        it "returns true" do
          expect(subject.created_at_diff?(diff_refs)).to be true
        end
      end

      context "when the diff refs don't match the original one of the diff note" do
        it "returns false" do
          expect(subject.created_at_diff?(merge_request.diff_refs)).to be false
        end
      end
    end
  end
end
