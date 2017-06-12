module SlashCommands
  class InterpretService < BaseService
    include Gitlab::SlashCommands::Dsl

    attr_reader :issuable

    # Takes a text and interprets the commands that are extracted from it.
    # Returns the content without commands, and hash of changes to be applied to a record.
    def execute(content, issuable)
      return [content, {}] unless current_user.can?(:use_slash_commands)

      @issuable = issuable
      @updates = {}

      content, commands = extractor.extract_commands(content, context)
      extract_updates(commands, context)
      [content, @updates]
    end

    # Takes a text and interprets the commands that are extracted from it.
    # Returns the content without commands, and array of changes explained.
    def explain(content, issuable)
      return [content, []] unless current_user.can?(:use_slash_commands)

      @issuable = issuable

      content, commands = extractor.extract_commands(content, context)
      commands = explain_commands(commands, context)
      [content, commands]
    end

    private

    def extractor
      Gitlab::SlashCommands::Extractor.new(self.class.command_definitions)
    end

    desc do
      "Close this #{issuable.to_ability_name.humanize(capitalize: false)}"
    end
    explanation do
      "Closes this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.persisted? &&
        issuable.open? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :close do
      @updates[:state_event] = 'close'
    end

    desc do
      "Reopen this #{issuable.to_ability_name.humanize(capitalize: false)}"
    end
    explanation do
      "Reopens this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.persisted? &&
        issuable.closed? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :reopen do
      @updates[:state_event] = 'reopen'
    end

    desc 'Merge (when the pipeline succeeds)'
    explanation 'Merges this merge request when the pipeline succeeds.'
    condition do
      last_diff_sha = params && params[:merge_request_diff_head_sha]
      issuable.is_a?(MergeRequest) &&
        issuable.persisted? &&
        issuable.mergeable_with_slash_command?(current_user, autocomplete_precheck: !last_diff_sha, last_diff_sha: last_diff_sha)
    end
    command :merge do
      @updates[:merge] = params[:merge_request_diff_head_sha]
    end

    desc 'Change title'
    explanation do |title_param|
      "Changes the title to \"#{title_param}\"."
    end
    params '<New title>'
    condition do
      issuable.persisted? &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :title do |title_param|
      @updates[:title] = title_param
    end

    desc 'Assign'
    explanation do |users|
      "Assigns #{users.first.to_reference}." if users.any?
    end
    params '@user'
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |assignee_param|
      extract_users(assignee_param)
    end
    command :assign do |users|
      next if users.empty?

      if issuable.is_a?(Issue)
        @updates[:assignee_ids] = [users.last.id]
      else
        @updates[:assignee_id] = users.last.id
      end
    end

    desc 'Remove assignee'
    explanation do
      "Removes assignee #{issuable.assignees.first.to_reference}."
    end
    condition do
      issuable.persisted? &&
        issuable.assignees.any? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :unassign do
      if issuable.is_a?(Issue)
        @updates[:assignee_ids] = []
      else
        @updates[:assignee_id] = nil
      end
    end

    desc 'Set milestone'
    explanation do |milestone|
      "Sets the milestone to #{milestone.to_reference}." if milestone
    end
    params '%"milestone"'
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", project) &&
        project.milestones.active.any?
    end
    parse_params do |milestone_param|
      extract_references(milestone_param, :milestone).first ||
        project.milestones.find_by(title: milestone_param.strip)
    end
    command :milestone do |milestone|
      @updates[:milestone_id] = milestone.id if milestone
    end

    desc 'Remove milestone'
    explanation do
      "Removes #{issuable.milestone.to_reference(format: :name)} milestone."
    end
    condition do
      issuable.persisted? &&
        issuable.milestone_id? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_milestone do
      @updates[:milestone_id] = nil
    end

    desc 'Add label(s)'
    explanation do |labels_param|
      labels = find_label_references(labels_param)

      "Adds #{labels.join(' ')} #{'label'.pluralize(labels.count)}." if labels.any?
    end
    params '~label1 ~"label 2"'
    condition do
      available_labels = LabelsFinder.new(current_user, project_id: project.id).execute

      current_user.can?(:"admin_#{issuable.to_ability_name}", project) &&
        available_labels.any?
    end
    command :label do |labels_param|
      label_ids = find_label_ids(labels_param)

      if label_ids.any?
        @updates[:add_label_ids] ||= []
        @updates[:add_label_ids] += label_ids

        @updates[:add_label_ids].uniq!
      end
    end

    desc 'Remove all or specific label(s)'
    explanation do |labels_param = nil|
      if labels_param.present?
        labels = find_label_references(labels_param)
        "Removes #{labels.join(' ')} #{'label'.pluralize(labels.count)}." if labels.any?
      else
        'Removes all labels.'
      end
    end
    params '~label1 ~"label 2"'
    condition do
      issuable.persisted? &&
        issuable.labels.any? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :unlabel do |labels_param = nil|
      if labels_param.present?
        label_ids = find_label_ids(labels_param)

        if label_ids.any?
          @updates[:remove_label_ids] ||= []
          @updates[:remove_label_ids] += label_ids

          @updates[:remove_label_ids].uniq!
        end
      else
        @updates[:label_ids] = []
      end
    end

    desc 'Replace all label(s)'
    explanation do |labels_param|
      labels = find_label_references(labels_param)
      "Replaces all labels with #{labels.join(' ')} #{'label'.pluralize(labels.count)}." if labels.any?
    end
    params '~label1 ~"label 2"'
    condition do
      issuable.persisted? &&
        issuable.labels.any? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :relabel do |labels_param|
      label_ids = find_label_ids(labels_param)

      if label_ids.any?
        @updates[:label_ids] ||= []
        @updates[:label_ids] += label_ids

        @updates[:label_ids].uniq!
      end
    end

    desc 'Add a todo'
    explanation 'Adds a todo.'
    condition do
      issuable.persisted? &&
        !TodoService.new.todo_exist?(issuable, current_user)
    end
    command :todo do
      @updates[:todo_event] = 'add'
    end

    desc 'Mark todo as done'
    explanation 'Marks todo as done.'
    condition do
      issuable.persisted? &&
        TodoService.new.todo_exist?(issuable, current_user)
    end
    command :done do
      @updates[:todo_event] = 'done'
    end

    desc 'Subscribe'
    explanation do
      "Subscribes to this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.persisted? &&
        !issuable.subscribed?(current_user, project)
    end
    command :subscribe do
      @updates[:subscription_event] = 'subscribe'
    end

    desc 'Unsubscribe'
    explanation do
      "Unsubscribes from this #{issuable.to_ability_name.humanize(capitalize: false)}."
    end
    condition do
      issuable.persisted? &&
        issuable.subscribed?(current_user, project)
    end
    command :unsubscribe do
      @updates[:subscription_event] = 'unsubscribe'
    end

    desc 'Set due date'
    explanation do |due_date|
      "Sets the due date to #{due_date.to_s(:medium)}." if due_date
    end
    params '<in 2 days | this Friday | December 31st>'
    condition do
      issuable.respond_to?(:due_date) &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |due_date_param|
      Chronic.parse(due_date_param).try(:to_date)
    end
    command :due do |due_date|
      @updates[:due_date] = due_date if due_date
    end

    desc 'Remove due date'
    explanation 'Removes the due date.'
    condition do
      issuable.persisted? &&
        issuable.respond_to?(:due_date) &&
        issuable.due_date? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_due_date do
      @updates[:due_date] = nil
    end

    desc 'Toggle the Work In Progress status'
    explanation do
      verb = issuable.work_in_progress? ? 'Unmarks' : 'Marks'
      noun = issuable.to_ability_name.humanize(capitalize: false)
      "#{verb} this #{noun} as Work In Progress."
    end
    condition do
      issuable.persisted? &&
        issuable.respond_to?(:work_in_progress?) &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable)
    end
    command :wip do
      @updates[:wip_event] = issuable.work_in_progress? ? 'unwip' : 'wip'
    end

    desc 'Toggle emoji award'
    explanation do |name|
      "Toggles :#{name}: emoji award." if name
    end
    params ':emoji:'
    condition do
      issuable.persisted?
    end
    parse_params do |emoji_param|
      match = emoji_param.match(Banzai::Filter::EmojiFilter.emoji_pattern)
      match[1] if match
    end
    command :award do |name|
      if name && issuable.user_can_award?(current_user, name)
        @updates[:emoji_award] = name
      end
    end

    desc 'Set time estimate'
    explanation do |time_estimate|
      time_estimate = Gitlab::TimeTrackingFormatter.output(time_estimate)

      "Sets time estimate to #{time_estimate}." if time_estimate
    end
    params '<1w 3d 2h 14m>'
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    parse_params do |raw_duration|
      Gitlab::TimeTrackingFormatter.parse(raw_duration)
    end
    command :estimate do |time_estimate|
      if time_estimate
        @updates[:time_estimate] = time_estimate
      end
    end

    desc 'Add or substract spent time'
    explanation do |time_spent|
      if time_spent
        if time_spent > 0
          verb = 'Adds'
          value = time_spent
        else
          verb = 'Substracts'
          value = -time_spent
        end

        "#{verb} #{Gitlab::TimeTrackingFormatter.output(value)} spent time."
      end
    end
    params '<1h 30m | -1h 30m>'
    condition do
      current_user.can?(:"admin_#{issuable.to_ability_name}", issuable)
    end
    parse_params do |raw_duration|
      Gitlab::TimeTrackingFormatter.parse(raw_duration)
    end
    command :spend do |time_spent|
      if time_spent
        @updates[:spend_time] = { duration: time_spent, user: current_user }
      end
    end

    desc 'Remove time estimate'
    explanation 'Removes time estimate.'
    condition do
      issuable.persisted? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_estimate do
      @updates[:time_estimate] = 0
    end

    desc 'Remove spent time'
    explanation 'Removes spent time.'
    condition do
      issuable.persisted? &&
        current_user.can?(:"admin_#{issuable.to_ability_name}", project)
    end
    command :remove_time_spent do
      @updates[:spend_time] = { duration: :reset, user: current_user }
    end

    # This is a dummy command, so that it appears in the autocomplete commands
    desc 'CC'
    params '@user'
    command :cc

    desc 'Define target branch for MR'
    explanation do |branch_name|
      "Sets target branch to #{branch_name}."
    end
    params '<Local branch name>'
    condition do
      issuable.respond_to?(:target_branch) &&
        (current_user.can?(:"update_#{issuable.to_ability_name}", issuable) ||
          issuable.new_record?)
    end
    parse_params do |target_branch_param|
      target_branch_param.strip
    end
    command :target_branch do |branch_name|
      @updates[:target_branch] = branch_name if project.repository.branch_names.include?(branch_name)
    end

    desc 'Move issue from one column of the board to another'
    explanation do |target_list_name|
      label = find_label_references(target_list_name).first
      "Moves issue to #{label} column in the board." if label
    end
    params '~"Target column"'
    condition do
      issuable.is_a?(Issue) &&
        current_user.can?(:"update_#{issuable.to_ability_name}", issuable) &&
        issuable.project.boards.count == 1
    end
    command :board_move do |target_list_name|
      label_ids = find_label_ids(target_list_name)

      if label_ids.size == 1
        label_id = label_ids.first

        # Ensure this label corresponds to a list on the board
        next unless Label.on_project_boards(issuable.project_id).where(id: label_id).exists?

        @updates[:remove_label_ids] =
          issuable.labels.on_project_boards(issuable.project_id).where.not(id: label_id).pluck(:id)
        @updates[:add_label_ids] = [label_id]
      end
    end

    def extract_users(params)
      return [] if params.nil?

      users = extract_references(params, :user)

      if users.empty?
        users = User.where(username: params.split(' ').map(&:strip))
      end

      users
    end

    def find_labels(labels_param)
      extract_references(labels_param, :label) |
        LabelsFinder.new(current_user, project_id: project.id, name: labels_param.split).execute
    end

    def find_label_references(labels_param)
      find_labels(labels_param).map(&:to_reference)
    end

    def find_label_ids(labels_param)
      find_labels(labels_param).map(&:id)
    end

    def explain_commands(commands, opts)
      commands.map do |name, arg|
        definition = self.class.definition_by_name(name)
        next unless definition

        definition.explain(self, opts, arg)
      end.compact
    end

    def extract_updates(commands, opts)
      commands.each do |name, arg|
        definition = self.class.definition_by_name(name)
        next unless definition

        definition.execute(self, opts, arg)
      end
    end

    def extract_references(arg, type)
      ext = Gitlab::ReferenceExtractor.new(project, current_user)
      ext.analyze(arg, author: current_user)

      ext.references(type)
    end

    def context
      {
        issuable: issuable,
        current_user: current_user,
        project: project,
        params: params
      }
    end
  end
end
