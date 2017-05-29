class IssueEntity < IssuableEntity
  expose :branch_name
  expose :confidential
  expose :assignees, using: API::Entities::UserBasic
  expose :due_date
  expose :moved_to_id
  expose :project_id
  expose :milestone, using: API::Entities::Milestone
  expose :labels, using: LabelEntity
end
