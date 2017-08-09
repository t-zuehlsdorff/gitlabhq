module Ci
  class PipelineTriggerService < BaseService
    def execute
      if trigger_from_token
        create_pipeline_from_trigger(trigger_from_token)
      end
    end

    private

    def create_pipeline_from_trigger(trigger)
      # this check is to not leak the presence of the project if user cannot read it
      return unless trigger.project == project

      pipeline = Ci::CreatePipelineService.new(project, trigger.owner, ref: params[:ref])
        .execute(:trigger, ignore_skip_ci: true) do |pipeline|
          trigger.trigger_requests.create!(pipeline: pipeline)
          create_pipeline_variables!(pipeline)
        end

      if pipeline.persisted?
        success(pipeline: pipeline)
      else
        error(pipeline.errors.messages, 400)
      end
    end

    def trigger_from_token
      return @trigger if defined?(@trigger)

      @trigger = Ci::Trigger.find_by_token(params[:token].to_s)
    end

    def create_pipeline_variables!(pipeline)
      return unless params[:variables]

      variables = params[:variables].map do |key, value|
        { key: key, value: value }
      end

      pipeline.variables.create!(variables)
    end
  end
end
