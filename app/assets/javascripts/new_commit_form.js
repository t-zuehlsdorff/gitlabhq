/* eslint-disable func-names, space-before-function-paren, no-var, prefer-rest-params, wrap-iife, no-return-assign, max-len */
(function() {
  this.NewCommitForm = (function() {
    function NewCommitForm(form, targetBranchName = 'target_branch') {
      this.form = form;
      this.targetBranchName = targetBranchName;
      this.renderDestination = this.renderDestination.bind(this);
      this.targetBranchDropdown = form.find('button.js-target-branch');
      this.originalBranch = form.find('.js-original-branch');
      this.createMergeRequest = form.find('.js-create-merge-request');
      this.createMergeRequestContainer = form.find('.js-create-merge-request-container');
      this.targetBranchDropdown.on('change.branch', this.renderDestination);
      this.renderDestination();
    }

    NewCommitForm.prototype.renderDestination = function() {
      var different;
      var targetBranch = this.form.find(`input[name="${this.targetBranchName}"]`);

      different = targetBranch.val() !== this.originalBranch.val();
      if (different) {
        this.createMergeRequestContainer.show();
        if (!this.wasDifferent) {
          this.createMergeRequest.prop('checked', true);
        }
      } else {
        this.createMergeRequestContainer.hide();
        this.createMergeRequest.prop('checked', false);
      }
      return this.wasDifferent = different;
    };

    return NewCommitForm;
  })();
}).call(window);
