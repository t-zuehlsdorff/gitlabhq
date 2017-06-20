require 'spec_helper'

describe Gitlab::Database, lib: true do
  before do
    stub_const('MigrationTest', Class.new { include Gitlab::Database })
  end

  describe '.config' do
    it 'returns a Hash' do
      expect(described_class.config).to be_an_instance_of(Hash)
    end
  end

  describe '.adapter_name' do
    it 'returns the name of the adapter' do
      expect(described_class.adapter_name).to be_an_instance_of(String)
    end
  end

  # These are just simple smoke tests to check if the methods work (regardless
  # of what they may return).
  describe '.mysql?' do
    subject { described_class.mysql? }

    it { is_expected.to satisfy { |val| val == true || val == false } }
  end

  describe '.postgresql?' do
    subject { described_class.postgresql? }

    it { is_expected.to satisfy { |val| val == true || val == false } }
  end

  describe '.version' do
    context "on mysql" do
      it "extracts the version number" do
        allow(described_class).to receive(:database_version).
          and_return("5.7.12-standard")

        expect(described_class.version).to eq '5.7.12-standard'
      end
    end

    context "on postgresql" do
      it "extracts the version number" do
        allow(described_class).to receive(:database_version).
          and_return("PostgreSQL 9.4.4 on x86_64-apple-darwin14.3.0")

        expect(described_class.version).to eq '9.4.4'
      end
    end
  end

  describe '.nulls_last_order' do
    context 'when using PostgreSQL' do
      before do
        expect(described_class).to receive(:postgresql?).and_return(true)
      end

      it { expect(described_class.nulls_last_order('column', 'ASC')).to eq 'column ASC NULLS LAST'}
      it { expect(described_class.nulls_last_order('column', 'DESC')).to eq 'column DESC NULLS LAST'}
    end

    context 'when using MySQL' do
      before do
        expect(described_class).to receive(:postgresql?).and_return(false)
      end

      it { expect(described_class.nulls_last_order('column', 'ASC')).to eq 'column IS NULL, column ASC'}
      it { expect(described_class.nulls_last_order('column', 'DESC')).to eq 'column DESC'}
    end
  end

  describe '.nulls_first_order' do
    context 'when using PostgreSQL' do
      before do
        expect(described_class).to receive(:postgresql?).and_return(true)
      end

      it { expect(described_class.nulls_first_order('column', 'ASC')).to eq 'column ASC NULLS FIRST'}
      it { expect(described_class.nulls_first_order('column', 'DESC')).to eq 'column DESC NULLS FIRST'}
    end

    context 'when using MySQL' do
      before do
        expect(described_class).to receive(:postgresql?).and_return(false)
      end

      it { expect(described_class.nulls_first_order('column', 'ASC')).to eq 'column ASC'}
      it { expect(described_class.nulls_first_order('column', 'DESC')).to eq 'column IS NULL, column DESC'}
    end
  end

  describe '.with_connection_pool' do
    it 'creates a new connection pool and disconnect it after used' do
      closed_pool = nil

      described_class.with_connection_pool(1) do |pool|
        pool.with_connection do |connection|
          connection.execute('SELECT 1 AS value')
        end

        expect(pool).to be_connected

        closed_pool = pool
      end

      expect(closed_pool).not_to be_connected
    end

    it 'disconnects the pool even an exception was raised' do
      error = Class.new(RuntimeError)
      closed_pool = nil

      begin
        described_class.with_connection_pool(1) do |pool|
          pool.with_connection do |connection|
            connection.execute('SELECT 1 AS value')
          end

          closed_pool = pool

          raise error.new('boom')
        end
      rescue error
      end

      expect(closed_pool).not_to be_connected
    end
  end

  describe '.create_connection_pool' do
    it 'creates a new connection pool with specific pool size' do
      pool = described_class.create_connection_pool(5)

      begin
        expect(pool)
          .to be_kind_of(ActiveRecord::ConnectionAdapters::ConnectionPool)

        expect(pool.spec.config[:pool]).to eq(5)
      ensure
        pool.disconnect!
      end
    end

    it 'allows setting of a custom hostname' do
      pool = described_class.create_connection_pool(5, '127.0.0.1')

      begin
        expect(pool.spec.config[:host]).to eq('127.0.0.1')
      ensure
        pool.disconnect!
      end
    end
  end

  describe '#true_value' do
    it 'returns correct value for PostgreSQL' do
      expect(described_class).to receive(:postgresql?).and_return(true)

      expect(described_class.true_value).to eq "'t'"
    end

    it 'returns correct value for MySQL' do
      expect(described_class).to receive(:postgresql?).and_return(false)

      expect(described_class.true_value).to eq 1
    end
  end

  describe '#false_value' do
    it 'returns correct value for PostgreSQL' do
      expect(described_class).to receive(:postgresql?).and_return(true)

      expect(described_class.false_value).to eq "'f'"
    end

    it 'returns correct value for MySQL' do
      expect(described_class).to receive(:postgresql?).and_return(false)

      expect(described_class.false_value).to eq 0
    end
  end
end
