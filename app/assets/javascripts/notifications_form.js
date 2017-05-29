/* eslint-disable func-names, space-before-function-paren, no-var, prefer-rest-params, wrap-iife, one-var, one-var-declaration-per-line, newline-per-chained-call, comma-dangle, consistent-return, prefer-arrow-callback, max-len */
(function() {
  this.NotificationsForm = (function() {
    function NotificationsForm() {
      this.toggleCheckbox = this.toggleCheckbox.bind(this);
      this.removeEventListeners();
      this.initEventListeners();
    }

    NotificationsForm.prototype.removeEventListeners = function() {
      return $(document).off('change', '.js-custom-notification-event');
    };

    NotificationsForm.prototype.initEventListeners = function() {
      return $(document).on('change', '.js-custom-notification-event', this.toggleCheckbox);
    };

    NotificationsForm.prototype.toggleCheckbox = function(e) {
      var $checkbox, $parent;
      $checkbox = $(e.currentTarget);
      $parent = $checkbox.closest('.checkbox');
      return this.saveEvent($checkbox, $parent);
    };

    NotificationsForm.prototype.showCheckboxLoadingSpinner = function($parent) {
      return $parent.addClass('is-loading').find('.custom-notification-event-loading').removeClass('fa-check').addClass('fa-spin fa-spinner').removeClass('is-done');
    };

    NotificationsForm.prototype.saveEvent = function($checkbox, $parent) {
      var form;
      form = $parent.parents('form:first');
      return $.ajax({
        url: form.attr('action'),
        method: form.attr('method'),
        dataType: 'json',
        data: form.serialize(),
        beforeSend: (function(_this) {
          return function() {
            return _this.showCheckboxLoadingSpinner($parent);
          };
        })(this)
      }).done(function(data) {
        $checkbox.enable();
        if (data.saved) {
          $parent.find('.custom-notification-event-loading').toggleClass('fa-spin fa-spinner fa-check is-done');
          return setTimeout(function() {
            return $parent.removeClass('is-loading').find('.custom-notification-event-loading').toggleClass('fa-spin fa-spinner fa-check is-done');
          }, 2000);
        }
      });
    };

    return NotificationsForm;
  })();
}).call(window);
