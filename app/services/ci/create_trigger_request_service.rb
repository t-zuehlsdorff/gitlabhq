module Ci
  class CreateTriggerRequestService
    def execute(project, trigger, ref, variables = nil)
      trigger_request = trigger.trigger_requests.create(variables: variables)

      pipeline = Ci::CreatePipelineService.new(project, trigger.owner, ref: ref).
        execute(ignore_skip_ci: true, trigger_request: trigger_request)

      trigger_request if pipeline.persisted?
    end
  end
end
