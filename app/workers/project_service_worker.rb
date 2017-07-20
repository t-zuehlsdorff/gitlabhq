class ProjectServiceWorker
  include Sidekiq::Worker
  include DedicatedSidekiqQueue

  sidekiq_options dead: false

  def perform(hook_id, data)
    data = data.with_indifferent_access
    Service.find(hook_id).execute(data)
  end
end
