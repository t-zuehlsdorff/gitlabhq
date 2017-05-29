class WebHookLog < ActiveRecord::Base
  belongs_to :web_hook

  serialize :request_headers, Hash
  serialize :request_data, Hash
  serialize :response_headers, Hash

  validates :web_hook, presence: true

  def success?
    response_status =~ /^2/
  end
end
