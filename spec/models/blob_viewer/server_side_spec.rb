require 'spec_helper'

describe BlobViewer::ServerSide, model: true do
  include FakeBlobHelpers

  let(:project) { build(:empty_project) }

  let(:viewer_class) do
    Class.new(BlobViewer::Base) do
      include BlobViewer::ServerSide
    end
  end

  subject { viewer_class.new(blob) }

  describe '#prepare!' do
    let(:blob) { fake_blob(path: 'file.txt') }

    it 'loads all blob data' do
      expect(blob).to receive(:load_all_data!)

      subject.prepare!
    end
  end

  describe '#render_error' do
    context 'when the blob is stored externally' do
      let(:project) { build(:empty_project, lfs_enabled: true) }

      let(:blob) { fake_blob(path: 'file.pdf', lfs: true) }

      before do
        allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)
      end

      it 'return :server_side_but_stored_externally' do
        expect(subject.render_error).to eq(:server_side_but_stored_externally)
      end
    end
  end
end
