module Groups
  class CreateService < Groups::BaseService
    def initialize(user, params = {})
      @current_user, @params = user, params.dup
      @chat_team = @params.delete(:create_chat_team)
    end

    def execute
      @group = Group.new(params)

      unless Gitlab::VisibilityLevel.allowed_for?(current_user, params[:visibility_level])
        deny_visibility_level(@group)
        return @group
      end

      if @group.parent && !can?(current_user, :create_subgroup, @group.parent)
        @group.parent = nil
        @group.errors.add(:parent_id, 'You don’t have permission to create a subgroup in this group.')

        return @group
      end

      @group.name ||= @group.path.dup

      if create_chat_team?
        response = Mattermost::CreateTeamService.new(@group, current_user).execute
        return @group if @group.errors.any?

        @group.build_chat_team(name: response['name'], team_id: response['id'])
      end

      @group.save
      @group.add_owner(current_user)
      @group
    end

    private

    def create_chat_team?
      Gitlab.config.mattermost.enabled && @chat_team && group.chat_team.nil?
    end
  end
end
