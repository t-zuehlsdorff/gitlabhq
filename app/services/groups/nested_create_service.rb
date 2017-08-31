module Groups
  class NestedCreateService < Groups::BaseService
    attr_reader :group_path

    def initialize(user, params)
      @current_user, @params = user, params.dup

      @group_path = @params.delete(:group_path)
    end

    def execute
      return nil unless group_path

      if group = Group.find_by_full_path(group_path)
        return group
      end

      if group_path.include?('/') && !Group.supports_nested_groups?
        raise 'Nested groups are not supported on MySQL'
      end

      create_group_path
    end

    private

    def create_group_path
      group_path_segments = group_path.split('/')

      last_group = nil
      partial_path_segments = []
      while subgroup_name = group_path_segments.shift
        partial_path_segments << subgroup_name
        partial_path = partial_path_segments.join('/')

        new_params = params.reverse_merge(
          path: subgroup_name,
          name: subgroup_name,
          parent: last_group
        )
        new_params[:visibility_level] ||= Gitlab::CurrentSettings.current_application_settings.default_group_visibility

        last_group = Group.find_by_full_path(partial_path) || Groups::CreateService.new(current_user, new_params).execute
      end

      last_group
    end
  end
end
