require 'spec_helper'

describe BuildSerializer do
  let(:user) { create(:user) }

  let(:serializer) do
    described_class.new(user: user)
  end

  subject { serializer.represent(resource) }

  describe '#represent' do
    context 'when a single object is being serialized' do
      let(:resource) { create(:ci_build) }

      it 'serializers the pipeline object' do
        expect(subject[:id]).to eq resource.id
      end
    end

    context 'when multiple objects are being serialized' do
      let(:resource) { create_list(:ci_build, 2) }

      it 'serializers the array of pipelines' do
        expect(subject).not_to be_empty
      end
    end
  end

  describe '#represent_status' do
    context 'when represents only status' do
      let(:resource) { create(:ci_build) }
      let(:status) { resource.detailed_status(double('user')) }

      subject { serializer.represent_status(resource) }

      it 'serializes only status' do
        expect(subject[:text]).to eq(status.text)
        expect(subject[:label]).to eq(status.label)
        expect(subject[:icon]).to eq(status.icon)
        expect(subject[:favicon]).to eq(status.favicon)
      end
    end
  end
end
