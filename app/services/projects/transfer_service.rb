# Projects::TransferService class
#
# Used for transfer project to another namespace
#
# Ex.
#   # Move projects to namespace with ID 17 by user
#   Projects::TransferService.new(project, user, namespace_id: 17).execute
#
module Projects
  class TransferService < BaseService
    include Gitlab::ShellAdapter
    TransferError = Class.new(StandardError)

    def execute(new_namespace)
      if new_namespace.blank?
        raise TransferError, 'Please select a new namespace for your project.'
      end
      unless allowed_transfer?(current_user, project, new_namespace)
        raise TransferError, 'Transfer failed, please contact an admin.'
      end
      transfer(project, new_namespace)
    rescue Projects::TransferService::TransferError => ex
      project.reload
      project.errors.add(:new_namespace, ex.message)
      false
    end

    def transfer(project, new_namespace)
      old_namespace = project.namespace

      Project.transaction do
        old_path = project.path_with_namespace
        old_group = project.group
        new_path = File.join(new_namespace.try(:full_path) || '', project.path)

        if Project.where(path: project.path, namespace_id: new_namespace.try(:id)).present?
          raise TransferError.new("Project with same path in target namespace already exists")
        end

        if project.has_container_registry_tags?
          # we currently doesn't support renaming repository if it contains tags in container registry
          raise TransferError.new('Project cannot be transferred, because tags are present in its container registry')
        end

        project.expire_caches_before_rename(old_path)

        # Apply new namespace id and visibility level
        project.namespace = new_namespace
        project.visibility_level = new_namespace.visibility_level unless project.visibility_level_allowed_by_group?
        project.save!

        # Notifications
        project.send_move_instructions(old_path)

        # Move main repository
        unless gitlab_shell.mv_repository(project.repository_storage_path, old_path, new_path)
          raise TransferError.new('Cannot move project')
        end

        # Move wiki repo also if present
        gitlab_shell.mv_repository(project.repository_storage_path, "#{old_path}.wiki", "#{new_path}.wiki")

        # Move missing group labels to project
        Labels::TransferService.new(current_user, old_group, project).execute

        # Move uploads
        Gitlab::UploadsTransfer.new.move_project(project.path, old_namespace.full_path, new_namespace.full_path)

        # Move pages
        Gitlab::PagesTransfer.new.move_project(project.path, old_namespace.full_path, new_namespace.full_path)

        project.old_path_with_namespace = old_path

        SystemHooksService.new.execute_hooks_for(project, :transfer)
      end

      refresh_permissions(old_namespace, new_namespace)

      true
    end

    def allowed_transfer?(current_user, project, namespace)
      namespace &&
        can?(current_user, :change_namespace, project) &&
        namespace.id != project.namespace_id &&
        current_user.can?(:create_projects, namespace)
    end

    def refresh_permissions(old_namespace, new_namespace)
      # This ensures we only schedule 1 job for every user that has access to
      # the namespaces.
      user_ids = old_namespace.user_ids_for_project_authorizations |
        new_namespace.user_ids_for_project_authorizations

      UserProjectAccessChangedService.new(user_ids).execute
    end
  end
end
