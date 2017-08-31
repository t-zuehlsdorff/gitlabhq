require 'spec_helper'

describe Gitlab::Git::Committer do
  let(:name) { 'Jane Doe' }
  let(:email) { 'janedoe@example.com' }
  let(:gl_id) { 'user-123' }

  subject { described_class.new(name, email, gl_id) }

  describe '#==' do
    def eq_other(name, email, gl_id)
      eq(described_class.new(name, email, gl_id))
    end

    it { expect(subject).to eq_other(name, email, gl_id) }

    it { expect(subject).not_to eq_other(nil, nil, nil) }
    it { expect(subject).not_to eq_other(name + 'x', email, gl_id) }
    it { expect(subject).not_to eq_other(name, email + 'x', gl_id) }
    it { expect(subject).not_to eq_other(name, email, gl_id + 'x') }
  end
end
