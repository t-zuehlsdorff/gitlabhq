require 'spec_helper'
require_relative '../email_shared_blocks'

describe Gitlab::Email::Handler::CreateNoteHandler do
  include_context :email_shared_context
  it_behaves_like :reply_processing_shared_examples

  before do
    stub_incoming_email_setting(enabled: true, address: "reply+%{key}@appmail.adventuretime.ooo")
    stub_config_setting(host: 'localhost')
  end

  let(:email_raw) { fixture_file('emails/valid_reply.eml') }
  let(:project)   { create(:project, :public, :repository) }
  let(:user)      { create(:user) }
  let(:note)      { create(:diff_note_on_merge_request, project: project) }
  let(:noteable)  { note.noteable }

  let!(:sent_notification) do
    SentNotification.record_note(note, user.id, mail_key)
  end

  context "when the recipient address doesn't include a mail key" do
    let(:email_raw) { fixture_file('emails/valid_reply.eml').gsub(mail_key, "") }

    it "raises a UnknownIncomingEmail" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::UnknownIncomingEmail)
    end
  end

  context "when no sent notification for the mail key could be found" do
    let(:email_raw) { fixture_file('emails/wrong_mail_key.eml') }

    it "raises a SentNotificationNotFoundError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::SentNotificationNotFoundError)
    end
  end

  context "when the noteable could not be found" do
    before do
      noteable.destroy
    end

    it "raises a NoteableNotFoundError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::NoteableNotFoundError)
    end
  end

  context "when the note could not be saved" do
    before do
      allow_any_instance_of(Note).to receive(:persisted?).and_return(false)
    end

    it "raises an InvalidNoteError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::InvalidNoteError)
    end

    context 'because the note was commands only' do
      let!(:email_raw) { fixture_file("emails/commands_only_reply.eml") }

      context 'and current user cannot update noteable' do
        it 'raises a CommandsOnlyNoteError' do
          expect { receiver.execute }.to raise_error(Gitlab::Email::InvalidNoteError)
        end
      end

      context 'and current user can update noteable' do
        before do
          project.team << [user, :developer]
        end

        it 'does not raise an error' do
          expect(TodoService.new.todo_exist?(noteable, user)).to be_falsy

          # One system note is created for the 'close' event
          expect { receiver.execute }.to change { noteable.notes.count }.by(1)

          expect(noteable.reload).to be_closed
          expect(TodoService.new.todo_exist?(noteable, user)).to be_truthy
        end
      end
    end
  end

  context 'when the note contains quick actions' do
    let!(:email_raw) { fixture_file("emails/commands_in_reply.eml") }

    context 'and current user cannot update noteable' do
      it 'post a note and does not update the noteable' do
        expect(TodoService.new.todo_exist?(noteable, user)).to be_falsy

        # One system note is created for the new note
        expect { receiver.execute }.to change { noteable.notes.count }.by(1)

        expect(noteable.reload).to be_open
        expect(TodoService.new.todo_exist?(noteable, user)).to be_falsy
      end
    end

    context 'and current user can update noteable' do
      before do
        project.team << [user, :developer]
      end

      it 'post a note and updates the noteable' do
        expect(TodoService.new.todo_exist?(noteable, user)).to be_falsy

        # One system note is created for the new note, one for the 'close' event
        expect { receiver.execute }.to change { noteable.notes.count }.by(2)

        expect(noteable.reload).to be_closed
        expect(TodoService.new.todo_exist?(noteable, user)).to be_truthy
      end
    end
  end

  context "when the reply is blank" do
    let!(:email_raw) { fixture_file("emails/no_content_reply.eml") }

    it "raises an EmptyEmailError" do
      expect { receiver.execute }.to raise_error(Gitlab::Email::EmptyEmailError)
    end
  end

  context "when everything is fine" do
    before do
      setup_attachment
    end

    it "creates a comment" do
      expect { receiver.execute }.to change { noteable.notes.count }.by(1)
      new_note = noteable.notes.last

      expect(new_note.author).to eq(sent_notification.recipient)
      expect(new_note.position).to eq(note.position)
      expect(new_note.note).to include("I could not disagree more.")
      expect(new_note.in_reply_to?(note)).to be_truthy
    end

    it "adds all attachments" do
      receiver.execute

      note = noteable.notes.last

      expect(note.note).to include(markdown)
    end

    context 'when sub-addressing is not supported' do
      before do
        stub_incoming_email_setting(enabled: true, address: nil)
      end

      shared_examples 'an email that contains a mail key' do |header|
        it "fetches the mail key from the #{header} header and creates a comment" do
          expect { receiver.execute }.to change { noteable.notes.count }.by(1)
          new_note = noteable.notes.last

          expect(new_note.author).to eq(sent_notification.recipient)
          expect(new_note.position).to eq(note.position)
          expect(new_note.note).to include('I could not disagree more.')
        end
      end

      context 'mail key is in the References header' do
        let(:email_raw) { fixture_file('emails/reply_without_subaddressing_and_key_inside_references.eml') }

        it_behaves_like 'an email that contains a mail key', 'References'
      end

      context 'mail key is in the References header with a comma' do
        let(:email_raw) { fixture_file('emails/reply_without_subaddressing_and_key_inside_references_with_a_comma.eml') }

        it_behaves_like 'an email that contains a mail key', 'References'
      end
    end
  end
end
