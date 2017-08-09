require 'spec_helper'

describe MergeRequestDiff do
  describe 'create new record' do
    subject { create(:merge_request).merge_request_diff }

    it { expect(subject).to be_valid }
    it { expect(subject).to be_persisted }
    it { expect(subject.commits.count).to eq(29) }
    it { expect(subject.diffs.count).to eq(20) }
    it { expect(subject.head_commit_sha).to eq('b83d6e391c22777fca1ed3012fce84f633d7fed0') }
    it { expect(subject.base_commit_sha).to eq('ae73cb07c9eeaf35924a10f713b364d32b2dd34f') }
    it { expect(subject.start_commit_sha).to eq('0b4bc9a49b562e85de7cc9e834518ea6828729b9') }
  end

  describe '#latest' do
    let!(:mr) { create(:merge_request, :with_diffs) }
    let!(:first_diff) { mr.merge_request_diff }
    let!(:last_diff) { mr.create_merge_request_diff }

    it { expect(last_diff.latest?).to be_truthy }
    it { expect(first_diff.latest?).to be_falsey }
  end

  describe '#diffs' do
    let(:mr) { create(:merge_request, :with_diffs) }
    let(:mr_diff) { mr.merge_request_diff }

    context 'when the :ignore_whitespace_change option is set' do
      it 'creates a new compare object instead of loading from the DB' do
        expect(mr_diff).not_to receive(:load_diffs)
        expect(Gitlab::Git::Compare).to receive(:new).and_call_original

        mr_diff.raw_diffs(ignore_whitespace_change: true)
      end
    end

    context 'when the raw diffs are empty' do
      before do
        MergeRequestDiffFile.delete_all(merge_request_diff_id: mr_diff.id)
      end

      it 'returns an empty DiffCollection' do
        expect(mr_diff.raw_diffs).to be_a(Gitlab::Git::DiffCollection)
        expect(mr_diff.raw_diffs).to be_empty
      end
    end

    context 'when the raw diffs have invalid content' do
      before do
        MergeRequestDiffFile.delete_all(merge_request_diff_id: mr_diff.id)
        mr_diff.update_attributes(st_diffs: ["--broken-diff"])
      end

      it 'returns an empty DiffCollection' do
        expect(mr_diff.raw_diffs.to_a).to be_empty
        expect(mr_diff.raw_diffs).to be_a(Gitlab::Git::DiffCollection)
        expect(mr_diff.raw_diffs).to be_empty
      end
    end

    context 'when the raw diffs exist' do
      it 'returns the diffs' do
        expect(mr_diff.raw_diffs).to be_a(Gitlab::Git::DiffCollection)
        expect(mr_diff.raw_diffs).not_to be_empty
      end

      context 'when the :paths option is set' do
        let(:diffs) { mr_diff.raw_diffs(paths: ['files/ruby/popen.rb', 'files/ruby/popen.rb']) }

        it 'only returns diffs that match the (old path, new path) given' do
          expect(diffs.map(&:new_path)).to contain_exactly('files/ruby/popen.rb')
        end

        it 'uses the diffs from the DB' do
          expect(mr_diff).to receive(:load_diffs)

          diffs
        end
      end
    end
  end

  describe '#save_diffs' do
    it 'saves collected state' do
      mr_diff = create(:merge_request).merge_request_diff

      expect(mr_diff.collected?).to be_truthy
    end

    it 'saves overflow state' do
      allow(Commit).to receive(:max_diff_options)
        .and_return(max_lines: 0, max_files: 0)

      mr_diff = create(:merge_request).merge_request_diff

      expect(mr_diff.overflow?).to be_truthy
    end

    it 'saves empty state' do
      allow_any_instance_of(described_class).to receive_message_chain(:compare, :commits)
        .and_return([])

      mr_diff = create(:merge_request).merge_request_diff

      expect(mr_diff.empty?).to be_truthy
    end

    it 'saves binary diffs correctly' do
      path = 'files/images/icn-time-tracking.pdf'
      mr_diff = create(:merge_request, source_branch: 'add-pdf-text-binary', target_branch: 'master').merge_request_diff
      diff_file = mr_diff.merge_request_diff_files.find_by(new_path: path)

      expect(diff_file).to be_binary
      expect(diff_file.diff).to eq(mr_diff.compare.diffs(paths: [path]).to_a.first.diff)
    end
  end

  describe '#commit_shas' do
    it 'returns all commits SHA using serialized commits' do
      subject.st_commits = [
        { id: 'sha1' },
        { id: 'sha2' }
      ]

      expect(subject.commit_shas).to eq(%w(sha1 sha2))
    end
  end

  describe '#compare_with' do
    subject { create(:merge_request, source_branch: 'fix').merge_request_diff }

    it 'delegates compare to the service' do
      expect(CompareService).to receive(:new).and_call_original

      subject.compare_with(nil)
    end

    it 'uses git diff A..B approach by default' do
      diffs = subject.compare_with('0b4bc9a49b562e85de7cc9e834518ea6828729b9').diffs

      expect(diffs.size).to eq(3)
    end
  end

  describe '#commits_count' do
    it 'returns number of commits using serialized commits' do
      subject.st_commits = [
        { id: 'sha1' },
        { id: 'sha2' }
      ]

      expect(subject.commits_count).to eq 2
    end
  end

  describe '#utf8_st_diffs' do
    it 'does not raise error when a hash value is in binary' do
      subject.st_diffs = [
        { diff: "\0" },
        { diff: "\x05\x00\x68\x65\x6c\x6c\x6f" }
      ]

      expect { subject.utf8_st_diffs }.not_to raise_error
    end
  end
end
