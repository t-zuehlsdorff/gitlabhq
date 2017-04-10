module Notes
  class CreateService < ::BaseService
    def execute
      merge_request_diff_head_sha = params.delete(:merge_request_diff_head_sha)

      note = Notes::BuildService.new(project, current_user, params).execute
      return note unless note.valid?

      # We execute commands (extracted from `params[:note]`) on the noteable
      # **before** we save the note because if the note consists of commands
      # only, there is no need be create a note!
      slash_commands_service = SlashCommandsService.new(project, current_user)

      if slash_commands_service.supported?(note)
        options = { merge_request_diff_head_sha: merge_request_diff_head_sha }
        content, command_params = slash_commands_service.extract_commands(note, options)

        only_commands = content.empty?

        note.note = content
      end

      note.run_after_commit do
        # Finish the harder work in the background
        NewNoteWorker.perform_async(note.id)
      end

      if !only_commands && note.save
        todo_service.new_note(note, current_user)
      end

      if command_params.present?
        slash_commands_service.execute(command_params, note)

        # We must add the error after we call #save because errors are reset
        # when #save is called
        if only_commands
          note.errors.add(:commands_only, 'Commands applied')
        end

        note.commands_changes = command_params
      end

      note
    end
  end
end
