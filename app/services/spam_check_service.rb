# SpamCheckService
#
# Provide helper methods for checking if a given spammable object has
# potential spam data.
#
# Dependencies:
# - params with :request
#
module SpamCheckService
  def filter_spam_check_params
    @request            = params.delete(:request)
    @api                = params.delete(:api)
    @recaptcha_verified = params.delete(:recaptcha_verified)
    @spam_log_id        = params.delete(:spam_log_id)
  end

  # In order to be proceed to the spam check process, @spammable has to be
  # a dirty instance, which means it should be already assigned with the new
  # attribute values.
  def spam_check(spammable, user)
    spam_service = SpamService.new(spammable, @request)

    spam_service.when_recaptcha_verified(@recaptcha_verified, @api) do
      user.spam_logs.find_by(id: @spam_log_id)&.update!(recaptcha_verified: true)
    end
  end
end
