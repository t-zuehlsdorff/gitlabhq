class PipelineSuccessWorker
  include Sidekiq::Worker
  include PipelineQueue

  enqueue_in group: :processing

  def perform(pipeline_id)
    Ci::Pipeline.find_by(id: pipeline_id).try do |pipeline|
      MergeRequests::MergeWhenPipelineSucceedsService
        .new(pipeline.project, nil)
        .trigger(pipeline)
    end
  end
end
