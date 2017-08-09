require 'spec_helper'
require_relative '../../config/initializers/1_settings'

describe Settings do
  describe '#repositories' do
    it 'assigns the default failure attributes' do
      repository_settings = Gitlab.config.repositories.storages['broken']

      expect(repository_settings['failure_count_threshold']).to eq(10)
      expect(repository_settings['failure_wait_time']).to eq(30)
      expect(repository_settings['failure_reset_time']).to eq(1800)
      expect(repository_settings['storage_timeout']).to eq(5)
    end
  end

  describe '#host_without_www' do
    context 'URL with protocol' do
      it 'returns the host' do
        expect(described_class.host_without_www('http://foo.com')).to eq 'foo.com'
        expect(described_class.host_without_www('http://www.foo.com')).to eq 'foo.com'
        expect(described_class.host_without_www('http://secure.foo.com')).to eq 'secure.foo.com'
        expect(described_class.host_without_www('http://www.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon')).to eq 'gravatar.com'

        expect(described_class.host_without_www('https://foo.com')).to eq 'foo.com'
        expect(described_class.host_without_www('https://www.foo.com')).to eq 'foo.com'
        expect(described_class.host_without_www('https://secure.foo.com')).to eq 'secure.foo.com'
        expect(described_class.host_without_www('https://secure.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon')).to eq 'secure.gravatar.com'
      end
    end

    context 'URL without protocol' do
      it 'returns the host' do
        expect(described_class.host_without_www('foo.com')).to eq 'foo.com'
        expect(described_class.host_without_www('www.foo.com')).to eq 'foo.com'
        expect(described_class.host_without_www('secure.foo.com')).to eq 'secure.foo.com'
        expect(described_class.host_without_www('www.gravatar.com/avatar/%{hash}?s=%{size}&d=identicon')).to eq 'gravatar.com'
      end

      context 'URL with user/port' do
        it 'returns the host' do
          expect(described_class.host_without_www('bob:pass@foo.com:8080')).to eq 'foo.com'
          expect(described_class.host_without_www('bob:pass@www.foo.com:8080')).to eq 'foo.com'
          expect(described_class.host_without_www('bob:pass@secure.foo.com:8080')).to eq 'secure.foo.com'
          expect(described_class.host_without_www('bob:pass@www.gravatar.com:8080/avatar/%{hash}?s=%{size}&d=identicon')).to eq 'gravatar.com'

          expect(described_class.host_without_www('http://bob:pass@foo.com:8080')).to eq 'foo.com'
          expect(described_class.host_without_www('http://bob:pass@www.foo.com:8080')).to eq 'foo.com'
          expect(described_class.host_without_www('http://bob:pass@secure.foo.com:8080')).to eq 'secure.foo.com'
          expect(described_class.host_without_www('http://bob:pass@www.gravatar.com:8080/avatar/%{hash}?s=%{size}&d=identicon')).to eq 'gravatar.com'
        end
      end
    end
  end
end
