/* global dateFormat */

import Pikaday from 'pikaday';

(() => {
  // Add datepickers to all `js-access-expiration-date` elements. If those elements are
  // children of an element with the `clearable-input` class, and have a sibling
  // `js-clear-input` element, then show that element when there is a value in the
  // datepicker, and make clicking on that element clear the field.
  //
  window.gl = window.gl || {};
  gl.MemberExpirationDate = (selector = '.js-access-expiration-date') => {
    function toggleClearInput() {
      $(this).closest('.clearable-input').toggleClass('has-value', $(this).val() !== '');
    }
    const inputs = $(selector);

    inputs.each((i, el) => {
      const $input = $(el);

      const calendar = new Pikaday({
        field: $input.get(0),
        theme: 'gitlab-theme animate-picker',
        format: 'yyyy-mm-dd',
        minDate: new Date(),
        container: $input.parent().get(0),
        onSelect(dateText) {
          $input.val(dateFormat(new Date(dateText), 'yyyy-mm-dd'));

          $input.trigger('change');

          toggleClearInput.call($input);
        },
      });

      calendar.setDate(new Date($input.val()));
      $input.data('pikaday', calendar);
    });

    inputs.next('.js-clear-input').on('click', function clicked(event) {
      event.preventDefault();

      const input = $(this).closest('.clearable-input').find(selector);
      const calendar = input.data('pikaday');

      calendar.setDate(null);
      input.trigger('change');
      toggleClearInput.call(input);
    });

    inputs.on('blur', toggleClearInput);

    inputs.each(toggleClearInput);
  };
}).call(window);
