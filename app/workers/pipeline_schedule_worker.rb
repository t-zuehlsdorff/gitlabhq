class PipelineScheduleWorker
  include Sidekiq::Worker
  include CronjobQueue

  def perform
    Ci::PipelineSchedule.active.where("next_run_at < ?", Time.now)
      .preload(:owner, :project).find_each do |schedule|
      begin
        unless schedule.runnable_by_owner?
          schedule.deactivate!
          next
        end

        Ci::CreatePipelineService.new(schedule.project,
                                      schedule.owner,
                                      ref: schedule.ref)
          .execute(:schedule, save_on_errors: false, schedule: schedule)
      rescue => e
        Rails.logger.error "#{schedule.id}: Failed to create a scheduled pipeline: #{e.message}"
      ensure
        schedule.schedule_next_run!
      end
    end
  end
end
