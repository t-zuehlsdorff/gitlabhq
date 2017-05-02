require 'spec_helper'

describe BlobViewer::Base, model: true do
  include FakeBlobHelpers

  let(:project) { build(:empty_project) }

  let(:viewer_class) do
    Class.new(described_class) do
      self.extensions = %w(pdf)
      self.max_size = 1.megabyte
      self.absolute_max_size = 5.megabytes
      self.client_side = false
    end
  end

  let(:viewer) { viewer_class.new(blob) }

  describe '.can_render?' do
    context 'when the extension is supported' do
      let(:blob) { fake_blob(path: 'file.pdf') }

      it 'returns true' do
        expect(viewer_class.can_render?(blob)).to be_truthy
      end
    end

    context 'when the extension is not supported' do
      let(:blob) { fake_blob(path: 'file.txt') }

      it 'returns false' do
        expect(viewer_class.can_render?(blob)).to be_falsey
      end
    end
  end

  describe '#too_large?' do
    context 'when the blob size is larger than the max size' do
      let(:blob) { fake_blob(path: 'file.pdf', size: 2.megabytes) }

      it 'returns true' do
        expect(viewer.too_large?).to be_truthy
      end
    end

    context 'when the blob size is smaller than the max size' do
      let(:blob) { fake_blob(path: 'file.pdf', size: 10.kilobytes) }

      it 'returns false' do
        expect(viewer.too_large?).to be_falsey
      end
    end
  end

  describe '#absolutely_too_large?' do
    context 'when the blob size is larger than the absolute max size' do
      let(:blob) { fake_blob(path: 'file.pdf', size: 10.megabytes) }

      it 'returns true' do
        expect(viewer.absolutely_too_large?).to be_truthy
      end
    end

    context 'when the blob size is smaller than the absolute max size' do
      let(:blob) { fake_blob(path: 'file.pdf', size: 2.megabytes) }

      it 'returns false' do
        expect(viewer.absolutely_too_large?).to be_falsey
      end
    end
  end

  describe '#can_override_max_size?' do
    context 'when the blob size is larger than the max size' do
      context 'when the blob size is larger than the absolute max size' do
        let(:blob) { fake_blob(path: 'file.pdf', size: 10.megabytes) }

        it 'returns false' do
          expect(viewer.can_override_max_size?).to be_falsey
        end
      end

      context 'when the blob size is smaller than the absolute max size' do
        let(:blob) { fake_blob(path: 'file.pdf', size: 2.megabytes) }

        it 'returns true' do
          expect(viewer.can_override_max_size?).to be_truthy
        end
      end
    end

    context 'when the blob size is smaller than the max size' do
      let(:blob) { fake_blob(path: 'file.pdf', size: 10.kilobytes) }

      it 'returns false' do
        expect(viewer.can_override_max_size?).to be_falsey
      end
    end
  end

  describe '#render_error' do
    context 'when the max size is overridden' do
      before do
        viewer.override_max_size = true
      end

      context 'when the blob size is larger than the absolute max size' do
        let(:blob) { fake_blob(path: 'file.pdf', size: 10.megabytes) }

        it 'returns :too_large' do
          expect(viewer.render_error).to eq(:too_large)
        end
      end

      context 'when the blob size is smaller than the absolute max size' do
        let(:blob) { fake_blob(path: 'file.pdf', size: 2.megabytes) }

        it 'returns nil' do
          expect(viewer.render_error).to be_nil
        end
      end
    end

    context 'when the max size is not overridden' do
      context 'when the blob size is larger than the max size' do
        let(:blob) { fake_blob(path: 'file.pdf', size: 2.megabytes) }

        it 'returns :too_large' do
          expect(viewer.render_error).to eq(:too_large)
        end
      end

      context 'when the blob size is smaller than the max size' do
        let(:blob) { fake_blob(path: 'file.pdf', size: 10.kilobytes) }

        it 'returns nil' do
          expect(viewer.render_error).to be_nil
        end
      end
    end

    context 'when the viewer is server side but the blob is stored in LFS' do
      let(:project) { build(:empty_project, lfs_enabled: true) }

      let(:blob) { fake_blob(path: 'file.pdf', lfs: true) }

      before do
        allow(Gitlab.config.lfs).to receive(:enabled).and_return(true)
      end

      it 'return :server_side_but_stored_in_lfs' do
        expect(viewer.render_error).to eq(:server_side_but_stored_in_lfs)
      end
    end
  end

  describe '#prepare!' do
    context 'when the viewer is server side' do
      let(:blob) { fake_blob(path: 'file.md') }

      before do
        viewer_class.client_side = false
      end

      it 'loads all blob data' do
        expect(blob).to receive(:load_all_data!)

        viewer.prepare!
      end
    end

    context 'when the viewer is client side' do
      let(:blob) { fake_blob(path: 'file.md') }

      before do
        viewer_class.client_side = true
      end

      it "doesn't load all blob data" do
        expect(blob).not_to receive(:load_all_data!)

        viewer.prepare!
      end
    end
  end
end
