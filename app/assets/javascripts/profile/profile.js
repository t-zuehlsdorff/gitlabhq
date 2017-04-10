/* eslint-disable comma-dangle, no-unused-vars, class-methods-use-this, quotes, consistent-return, func-names, prefer-arrow-callback, space-before-function-paren, max-len */
/* global Flash */

((global) => {
  class Profile {
    constructor({ form } = {}) {
      this.onSubmitForm = this.onSubmitForm.bind(this);
      this.form = form || $('.edit-user');
      this.bindEvents();
      this.initAvatarGlCrop();
    }

    initAvatarGlCrop() {
      const cropOpts = {
        filename: '.js-avatar-filename',
        previewImage: '.avatar-image .avatar',
        modalCrop: '.modal-profile-crop',
        pickImageEl: '.js-choose-user-avatar-button',
        uploadImageBtn: '.js-upload-user-avatar',
        modalCropImg: '.modal-profile-crop-image'
      };
      this.avatarGlCrop = $('.js-user-avatar-input').glCrop(cropOpts).data('glcrop');
    }

    bindEvents() {
      $('.js-preferences-form').on('change.preference', 'input[type=radio]', this.submitForm);
      $('#user_notification_email').on('change', this.submitForm);
      $('#user_notified_of_own_activity').on('change', this.submitForm);
      $('.update-username').on('ajax:before', this.beforeUpdateUsername);
      $('.update-username').on('ajax:complete', this.afterUpdateUsername);
      $('.update-notifications').on('ajax:success', this.onUpdateNotifs);
      this.form.on('submit', this.onSubmitForm);
    }

    submitForm() {
      return $(this).parents('form').submit();
    }

    onSubmitForm(e) {
      e.preventDefault();
      return this.saveForm();
    }

    beforeUpdateUsername() {
      $('.loading-username', this).removeClass('hidden');
    }

    afterUpdateUsername() {
      $('.loading-username', this).addClass('hidden');
      $('button[type=submit]', this).enable();
    }

    onUpdateNotifs(e, data) {
      return data.saved ?
        new Flash("Notification settings saved", "notice") :
        new Flash("Failed to save new settings", "alert");
    }

    saveForm() {
      const self = this;
      const formData = new FormData(this.form[0]);
      const avatarBlob = this.avatarGlCrop.getBlob();

      if (avatarBlob != null) {
        formData.append('user[avatar]', avatarBlob, 'avatar.png');
      }

      return $.ajax({
        url: this.form.attr('action'),
        type: this.form.attr('method'),
        data: formData,
        dataType: "json",
        processData: false,
        contentType: false,
        success: response => new Flash(response.message, 'notice'),
        error: jqXHR => new Flash(jqXHR.responseJSON.message, 'alert'),
        complete: () => {
          window.scrollTo(0, 0);
          // Enable submit button after requests ends
          return self.form.find(':input[disabled]').enable();
        }
      });
    }
  }

  $(function() {
    $(document).on('input.ssh_key', '#key_key', function() {
      const $title = $('#key_title');
      const comment = $(this).val().match(/^\S+ \S+ (.+)\n?$/);

      // Extract the SSH Key title from its comment
      if (comment && comment.length > 1) {
        return $title.val(comment[1]).change();
      }
    });
    if (global.utils.getPagePath() === 'profiles') {
      return new Profile();
    }
  });
})(window.gl || (window.gl = {}));
