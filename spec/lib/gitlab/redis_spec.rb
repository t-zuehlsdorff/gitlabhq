require 'spec_helper'

describe Gitlab::Redis do
  include StubENV

  let(:config) { 'config/resque.yml' }

  before(:each) do
    stub_env('GITLAB_REDIS_CONFIG_FILE', Rails.root.join(config).to_s)
    clear_raw_config
  end

  after(:each) do
    clear_raw_config
  end

  describe '.params' do
    subject { described_class.params }

    it 'withstands mutation' do
      params1 = described_class.params
      params2 = described_class.params
      params1[:foo] = :bar

      expect(params2).not_to have_key(:foo)
    end

    context 'when url contains unix socket reference' do
      let(:config_old) { 'spec/fixtures/config/redis_old_format_socket.yml' }
      let(:config_new) { 'spec/fixtures/config/redis_new_format_socket.yml' }

      context 'with old format' do
        let(:config) { config_old }

        it 'returns path key instead' do
          is_expected.to include(path: '/path/to/old/redis.sock')
          is_expected.not_to have_key(:url)
        end
      end

      context 'with new format' do
        let(:config) { config_new }

        it 'returns path key instead' do
          is_expected.to include(path: '/path/to/redis.sock')
          is_expected.not_to have_key(:url)
        end
      end
    end

    context 'when url is host based' do
      let(:config_old) { 'spec/fixtures/config/redis_old_format_host.yml' }
      let(:config_new) { 'spec/fixtures/config/redis_new_format_host.yml' }

      context 'with old format' do
        let(:config) { config_old }

        it 'returns hash with host, port, db, and password' do
          is_expected.to include(host: 'localhost', password: 'mypassword', port: 6379, db: 99)
          is_expected.not_to have_key(:url)
        end
      end

      context 'with new format' do
        let(:config) { config_new }

        it 'returns hash with host, port, db, and password' do
          is_expected.to include(host: 'localhost', password: 'mynewpassword', port: 6379, db: 99)
          is_expected.not_to have_key(:url)
        end
      end
    end
  end

  describe '.url' do
    it 'withstands mutation' do
      url1 = described_class.url
      url2 = described_class.url
      url1 << 'foobar'

      expect(url2).not_to end_with('foobar')
    end

    context 'when yml file with env variable' do
      let(:config) { 'spec/fixtures/config/redis_config_with_env.yml' }

      before  do
        stub_env('TEST_GITLAB_REDIS_URL', 'redis://redishost:6379')
      end

      it 'reads redis url from env variable' do
        expect(described_class.url).to eq 'redis://redishost:6379'
      end
    end
  end

  describe '._raw_config' do
    subject { described_class._raw_config }
    let(:config) { '/var/empty/doesnotexist' }

    it 'should be frozen' do
      expect(subject).to be_frozen
    end

    it 'returns false when the file does not exist' do
      expect(subject).to eq(false)
    end
  end

  describe '.with' do
    before do
      clear_pool
    end

    after do
      clear_pool
    end

    context 'when running not on sidekiq workers' do
      before do
        allow(Sidekiq).to receive(:server?).and_return(false)
      end

      it 'instantiates a connection pool with size 5' do
        expect(ConnectionPool).to receive(:new).with(size: 5).and_call_original

        described_class.with { |_redis| true }
      end
    end

    context 'when running on sidekiq workers' do
      before do
        allow(Sidekiq).to receive(:server?).and_return(true)
        allow(Sidekiq).to receive(:options).and_return({ concurrency: 18 })
      end

      it 'instantiates a connection pool with a size based on the concurrency of the worker' do
        expect(ConnectionPool).to receive(:new).with(size: 18 + 5).and_call_original

        described_class.with { |_redis| true }
      end
    end
  end

  describe '#sentinels' do
    subject { described_class.new(Rails.env).sentinels }

    context 'when sentinels are defined' do
      let(:config) { 'spec/fixtures/config/redis_new_format_host.yml' }

      it 'returns an array of hashes with host and port keys' do
        is_expected.to include(host: 'localhost', port: 26380)
        is_expected.to include(host: 'slave2', port: 26381)
      end
    end

    context 'when sentinels are not defined' do
      let(:config) { 'spec/fixtures/config/redis_old_format_host.yml' }

      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#sentinels?' do
    subject { described_class.new(Rails.env).sentinels? }

    context 'when sentinels are defined' do
      let(:config) { 'spec/fixtures/config/redis_new_format_host.yml' }

      it 'returns true' do
        is_expected.to be_truthy
      end
    end

    context 'when sentinels are not defined' do
      let(:config) { 'spec/fixtures/config/redis_old_format_host.yml' }

      it 'returns false' do
        is_expected.to be_falsey
      end
    end
  end

  describe '#raw_config_hash' do
    it 'returns default redis url when no config file is present' do
      expect(subject).to receive(:fetch_config) { false }

      expect(subject.send(:raw_config_hash)).to eq(url: Gitlab::Redis::DEFAULT_REDIS_URL)
    end

    it 'returns old-style single url config in a hash' do
      expect(subject).to receive(:fetch_config) { 'redis://myredis:6379' }
      expect(subject.send(:raw_config_hash)).to eq(url: 'redis://myredis:6379')
    end
  end

  describe '#fetch_config' do
    it 'returns false when no config file is present' do
      allow(described_class).to receive(:_raw_config) { false }

      expect(subject.send(:fetch_config)).to be_falsey
    end
  end

  def clear_raw_config
    described_class.remove_instance_variable(:@_raw_config)
  rescue NameError
    # raised if @_raw_config was not set; ignore
  end

  def clear_pool
    described_class.remove_instance_variable(:@pool)
  rescue NameError
    # raised if @pool was not set; ignore
  end
end
