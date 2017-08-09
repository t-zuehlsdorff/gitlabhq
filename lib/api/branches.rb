require 'mime/types'

module API
  class Branches < Grape::API
    include PaginationParams

    BRANCH_ENDPOINT_REQUIREMENTS = API::PROJECT_ENDPOINT_REQUIREMENTS.merge(branch: API::NO_SLASH_URL_PART_REGEX)

    before { authorize! :download_code, user_project }

    params do
      requires :id, type: String, desc: 'The ID of a project'
    end
    resource :projects, requirements: API::PROJECT_ENDPOINT_REQUIREMENTS do
      desc 'Get a project repository branches' do
        success Entities::RepoBranch
      end
      params do
        use :pagination
      end
      get ':id/repository/branches' do
        branches = ::Kaminari.paginate_array(user_project.repository.branches.sort_by(&:name))

        present paginate(branches), with: Entities::RepoBranch, project: user_project
      end

      desc 'Get a single branch' do
        success Entities::RepoBranch
      end
      params do
        requires :branch, type: String, desc: 'The name of the branch'
      end
      get ':id/repository/branches/:branch', requirements: BRANCH_ENDPOINT_REQUIREMENTS do
        branch = user_project.repository.find_branch(params[:branch])
        not_found!("Branch") unless branch

        present branch, with: Entities::RepoBranch, project: user_project
      end

      # Note: This API will be deprecated in favor of the protected branches API.
      # Note: The internal data model moved from `developers_can_{merge,push}` to `allowed_to_{merge,push}`
      # in `gitlab-org/gitlab-ce!5081`. The API interface has not been changed (to maintain compatibility),
      # but it works with the changed data model to infer `developers_can_merge` and `developers_can_push`.
      desc 'Protect a single branch' do
        success Entities::RepoBranch
      end
      params do
        requires :branch, type: String, desc: 'The name of the branch'
        optional :developers_can_push, type: Boolean, desc: 'Flag if developers can push to that branch'
        optional :developers_can_merge, type: Boolean, desc: 'Flag if developers can merge to that branch'
      end
      put ':id/repository/branches/:branch/protect', requirements: BRANCH_ENDPOINT_REQUIREMENTS do
        authorize_admin_project

        branch = user_project.repository.find_branch(params[:branch])
        not_found!('Branch') unless branch

        protected_branch = user_project.protected_branches.find_by(name: branch.name)

        protected_branch_params = {
          name: branch.name,
          developers_can_push: params[:developers_can_push],
          developers_can_merge: params[:developers_can_merge]
        }

        service_args = [user_project, current_user, protected_branch_params]

        protected_branch = if protected_branch
                             ::ProtectedBranches::ApiUpdateService.new(*service_args).execute(protected_branch)
                           else
                             ::ProtectedBranches::ApiCreateService.new(*service_args).execute
                           end

        if protected_branch.valid?
          present branch, with: Entities::RepoBranch, project: user_project
        else
          render_api_error!(protected_branch.errors.full_messages, 422)
        end
      end

      # Note: This API will be deprecated in favor of the protected branches API.
      desc 'Unprotect a single branch' do
        success Entities::RepoBranch
      end
      params do
        requires :branch, type: String, desc: 'The name of the branch'
      end
      put ':id/repository/branches/:branch/unprotect', requirements: BRANCH_ENDPOINT_REQUIREMENTS do
        authorize_admin_project

        branch = user_project.repository.find_branch(params[:branch])
        not_found!("Branch") unless branch
        protected_branch = user_project.protected_branches.find_by(name: branch.name)
        protected_branch&.destroy

        present branch, with: Entities::RepoBranch, project: user_project
      end

      desc 'Create branch' do
        success Entities::RepoBranch
      end
      params do
        requires :branch, type: String, desc: 'The name of the branch'
        requires :ref, type: String, desc: 'Create branch from commit sha or existing branch'
      end
      post ':id/repository/branches' do
        authorize_push_project

        result = CreateBranchService.new(user_project, current_user)
                 .execute(params[:branch], params[:ref])

        if result[:status] == :success
          present result[:branch],
                  with: Entities::RepoBranch,
                  project: user_project
        else
          render_api_error!(result[:message], 400)
        end
      end

      desc 'Delete a branch'
      params do
        requires :branch, type: String, desc: 'The name of the branch'
      end
      delete ':id/repository/branches/:branch', requirements: BRANCH_ENDPOINT_REQUIREMENTS do
        authorize_push_project

        result = DeleteBranchService.new(user_project, current_user)
                 .execute(params[:branch])

        if result[:status] != :success
          render_api_error!(result[:message], result[:return_code])
        end
      end

      desc 'Delete all merged branches'
      delete ':id/repository/merged_branches' do
        DeleteMergedBranchesService.new(user_project, current_user).async_execute

        accepted!
      end
    end
  end
end
