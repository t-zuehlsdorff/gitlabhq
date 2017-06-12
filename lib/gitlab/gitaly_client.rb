require 'gitaly'

module Gitlab
  module GitalyClient
    module MigrationStatus
      DISABLED = 1
      OPT_IN = 2
      OPT_OUT = 3
    end

    SERVER_VERSION_FILE = 'GITALY_SERVER_VERSION'.freeze

    MUTEX = Mutex.new
    private_constant :MUTEX

    def self.stub(name, storage)
      MUTEX.synchronize do
        @stubs ||= {}
        @stubs[storage] ||= {}
        @stubs[storage][name] ||= begin
          klass = Gitaly.const_get(name.to_s.camelcase.to_sym).const_get(:Stub)
          addr = address(storage)
          addr = addr.sub(%r{^tcp://}, '') if URI(addr).scheme == 'tcp'
          klass.new(addr, :this_channel_is_insecure)
        end
      end
    end

    def self.clear_stubs!
      MUTEX.synchronize do
        @stubs = nil
      end
    end

    def self.address(storage)
      params = Gitlab.config.repositories.storages[storage]
      raise "storage not found: #{storage.inspect}" if params.nil?

      address = params['gitaly_address']
      unless address.present?
        raise "storage #{storage.inspect} is missing a gitaly_address"
      end

      unless URI(address).scheme.in?(%w(tcp unix))
        raise "Unsupported Gitaly address: #{address.inspect} does not use URL scheme 'tcp' or 'unix'"
      end

      address
    end

    def self.enabled?
      Gitlab.config.gitaly.enabled
    end

    def self.feature_enabled?(feature, status: MigrationStatus::OPT_IN)
      return false if !enabled? || status == MigrationStatus::DISABLED

      feature = Feature.get("gitaly_#{feature}")

      # If the feature hasn't been set, turn it on if it's opt-out
      return status == MigrationStatus::OPT_OUT unless Feature.persisted?(feature)

      if feature.percentage_of_time_value > 0
        # Probabilistically enable this feature
        return Random.rand() * 100 < feature.percentage_of_time_value
      end

      feature.enabled?
    end

    def self.migrate(feature)
      is_enabled  = feature_enabled?(feature)
      metric_name = feature.to_s
      metric_name += "_gitaly" if is_enabled

      Gitlab::Metrics.measure(metric_name) do
        yield is_enabled
      end
    end

    def self.expected_server_version
      path = Rails.root.join(SERVER_VERSION_FILE)
      path.read.chomp
    end
  end
end
