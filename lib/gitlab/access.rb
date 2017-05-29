# Gitlab::Access module
#
# Define allowed roles that can be used
# in GitLab code to determine authorization level
#
module Gitlab
  module Access
    AccessDeniedError = Class.new(StandardError)

    NO_ACCESS = 0
    GUEST     = 10
    REPORTER  = 20
    DEVELOPER = 30
    MASTER    = 40
    OWNER     = 50

    # Branch protection settings
    PROTECTION_NONE          = 0
    PROTECTION_DEV_CAN_PUSH  = 1
    PROTECTION_FULL          = 2
    PROTECTION_DEV_CAN_MERGE = 3

    class << self
      delegate :values, to: :options

      def all_values
        options_with_owner.values
      end

      def options
        {
          "Guest"     => GUEST,
          "Reporter"  => REPORTER,
          "Developer" => DEVELOPER,
          "Master"    => MASTER
        }
      end

      def options_with_owner
        options.merge(
          "Owner" => OWNER
        )
      end

      def sym_options
        {
          guest:     GUEST,
          reporter:  REPORTER,
          developer: DEVELOPER,
          master:    MASTER
        }
      end

      def sym_options_with_owner
        sym_options.merge(owner: OWNER)
      end

      def protection_options
        {
          "Not protected: Both developers and masters can push new commits, force push, or delete the branch." => PROTECTION_NONE,
          "Protected against pushes: Developers cannot push new commits, but are allowed to accept merge requests to the branch." => PROTECTION_DEV_CAN_MERGE,
          "Partially protected: Developers can push new commits, but cannot force push or delete the branch. Masters can do all of those." => PROTECTION_DEV_CAN_PUSH,
          "Fully protected: Developers cannot push new commits, force push, or delete the branch. Only masters can do any of those." => PROTECTION_FULL
        }
      end

      def protection_values
        protection_options.values
      end
    end

    def human_access
      Gitlab::Access.options_with_owner.key(access_field)
    end

    def owner?
      access_field == OWNER
    end
  end
end
