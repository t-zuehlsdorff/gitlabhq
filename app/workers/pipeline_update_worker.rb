class PipelineUpdateWorker
  include Sidekiq::Worker
  include PipelineQueue

  enqueue_in group: :processing

  def perform(pipeline_id)
    Ci::Pipeline.find_by(id: pipeline_id)
      .try(:update_status)
  end
end
