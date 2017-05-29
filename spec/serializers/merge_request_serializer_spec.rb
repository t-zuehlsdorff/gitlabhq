require 'spec_helper'

describe MergeRequestSerializer do
  let(:user) { build_stubbed(:user) }
  let(:merge_request) { build_stubbed(:merge_request) }

  let(:serializer) do
    described_class.new(current_user: user)
  end

  describe '#represent' do
    let(:opts) { { basic: basic } }
    subject { serializer.represent(merge_request, basic: basic) }

    context 'when basic param is truthy' do
      let(:basic) { true }

      it 'calls super class #represent with correct params' do
        expect_any_instance_of(BaseSerializer).to receive(:represent)
          .with(merge_request, opts, MergeRequestBasicEntity)

        subject
      end
    end

    context 'when basic param is falsy' do
      let(:basic) { false }

      it 'calls super class #represent with correct params' do
        expect_any_instance_of(BaseSerializer).to receive(:represent)
          .with(merge_request, opts, MergeRequestEntity)

        subject
      end
    end
  end
end
