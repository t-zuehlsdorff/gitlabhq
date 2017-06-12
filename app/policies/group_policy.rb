class GroupPolicy < BasePolicy
  def rules
    can! :read_group if @subject.public?
    return unless @user

    globally_viewable = @subject.public? || (@subject.internal? && !@user.external?)
    access_level = @subject.max_member_access_for_user(@user)
    owner = access_level >= GroupMember::OWNER
    master = access_level >= GroupMember::MASTER
    reporter = access_level >= GroupMember::REPORTER

    can_read = false
    can_read ||= globally_viewable
    can_read ||= access_level >= GroupMember::GUEST
    can_read ||= GroupProjectsFinder.new(group: @subject, current_user: @user).execute.any?
    can! :read_group if can_read

    if reporter
      can! :admin_label
    end

    # Only group masters and group owners can create new projects
    if master
      can! :create_projects
      can! :admin_milestones
    end

    # Only group owner and administrators can admin group
    if owner
      can! :admin_group
      can! :admin_namespace
      can! :admin_group_member
      can! :change_visibility_level
      can! :create_subgroup if @user.can_create_group
    end

    if globally_viewable && @subject.request_access_enabled && access_level == GroupMember::NO_ACCESS
      can! :request_access
    end
  end

  def can_read_group?
    return true if @subject.public?
    return true if @user.admin?
    return true if @subject.internal? && !@user.external?
    return true if @subject.users.include?(@user)

    GroupProjectsFinder.new(group: @subject, current_user: @user).execute.any?
  end
end
