# Gitaly note: JV: no RPC's here.

module Gitlab
  module Git
    # Ephemeral (per request) storage for environment variables that some Git
    # commands may need.
    #
    # For example, in pre-receive hooks, new objects are put in a temporary
    # $GIT_OBJECT_DIRECTORY. Without it set, the new objects cannot be retrieved
    # (this would break push rules for instance).
    #
    # This class is thread-safe via RequestStore.
    class Env
      WHITELISTED_GIT_VARIABLES = %w[
        GIT_OBJECT_DIRECTORY
        GIT_ALTERNATE_OBJECT_DIRECTORIES
      ].freeze

      def self.set(env)
        return unless RequestStore.active?

        RequestStore.store[:gitlab_git_env] = whitelist_git_env(env)
      end

      def self.all
        return {} unless RequestStore.active?

        RequestStore.fetch(:gitlab_git_env) { {} }
      end

      def self.[](key)
        all[key]
      end

      def self.whitelist_git_env(env)
        env.select { |key, _| WHITELISTED_GIT_VARIABLES.include?(key.to_s) }.with_indifferent_access
      end
    end
  end
end
