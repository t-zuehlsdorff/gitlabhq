class MergeRequestSerializer < BaseSerializer
  # This overrided method takes care of which entity should be used
  # to serialize the `merge_request` based on `basic` key in `opts` param.
  # Hence, `entity` doesn't need to be declared on the class scope.
  def represent(merge_request, opts = {})
    entity = opts[:basic] ? MergeRequestBasicEntity : MergeRequestEntity
    super(merge_request, opts, entity)
  end
end
