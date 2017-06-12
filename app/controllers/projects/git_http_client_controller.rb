# This file should be identical in GitLab Community Edition and Enterprise Edition

class Projects::GitHttpClientController < Projects::ApplicationController
  include ActionController::HttpAuthentication::Basic
  include KerberosSpnegoHelper

  attr_reader :authentication_result

  delegate :actor, :authentication_abilities, to: :authentication_result, allow_nil: true

  alias_method :user, :actor

  # Git clients will not know what authenticity token to send along
  skip_before_action :verify_authenticity_token
  skip_before_action :repository
  before_action :authenticate_user
  before_action :ensure_project_found!

  private

  def download_request?
    raise NotImplementedError
  end

  def upload_request?
    raise NotImplementedError
  end

  def authenticate_user
    @authentication_result = Gitlab::Auth::Result.new

    if allow_basic_auth? && basic_auth_provided?
      login, password = user_name_and_password(request)

      if handle_basic_authentication(login, password)
        return # Allow access
      end
    elsif allow_kerberos_spnego_auth? && spnego_provided?
      kerberos_user = find_kerberos_user

      if kerberos_user
        @authentication_result = Gitlab::Auth::Result.new(
          kerberos_user, nil, :kerberos, Gitlab::Auth.full_authentication_abilities)

        send_final_spnego_response
        return # Allow access
      end
    elsif project && download_request? && Guest.can?(:download_code, project)
      @authentication_result = Gitlab::Auth::Result.new(nil, project, :none, [:download_code])

      return # Allow access
    end

    send_challenges
    render plain: "HTTP Basic: Access denied\n", status: 401
  rescue Gitlab::Auth::MissingPersonalTokenError
    render_missing_personal_token
  end

  def basic_auth_provided?
    has_basic_credentials?(request)
  end

  def send_challenges
    challenges = []
    challenges << 'Basic realm="GitLab"' if allow_basic_auth?
    challenges << spnego_challenge if allow_kerberos_spnego_auth?
    headers['Www-Authenticate'] = challenges.join("\n") if challenges.any?
  end

  def ensure_project_found!
    render_not_found if project.blank?
  end

  def project
    return @project if defined?(@project)

    project_id, _ = project_id_with_suffix
    @project =
      if project_id.blank?
        nil
      else
        Project.find_by_full_path("#{params[:namespace_id]}/#{project_id}")
      end
  end

  # This method returns two values so that we can parse
  # params[:project_id] (untrusted input!) in exactly one place.
  def project_id_with_suffix
    id = params[:project_id] || ''

    %w[.wiki.git .git].each do |suffix|
      if id.end_with?(suffix)
        # Be careful to only remove the suffix from the end of 'id'.
        # Accidentally removing it from the middle is how security
        # vulnerabilities happen!
        return [id.slice(0, id.length - suffix.length), suffix]
      end
    end

    # Something is wrong with params[:project_id]; do not pass it on.
    [nil, nil]
  end

  def render_missing_personal_token
    render plain: "HTTP Basic: Access denied\n" \
                  "You have 2FA enabled, please use a personal access token for Git over HTTP.\n" \
                  "You can generate one at #{profile_personal_access_tokens_url}",
           status: 401
  end

  def repository
    wiki? ? project.wiki.repository : project.repository
  end

  def wiki?
    return @wiki if defined?(@wiki)

    _, suffix = project_id_with_suffix
    @wiki = suffix == '.wiki.git'
  end

  def render_not_found
    render plain: 'Not Found', status: :not_found
  end

  def handle_basic_authentication(login, password)
    @authentication_result = Gitlab::Auth.find_for_git_client(
      login, password, project: project, ip: request.ip)

    @authentication_result.success?
  end

  def ci?
    authentication_result.ci?(project)
  end
end
