/* eslint-disable no-param-reassign, func-names, no-var, camelcase, no-unused-vars, object-shorthand, space-before-function-paren, no-return-assign, comma-dangle, consistent-return, one-var, one-var-declaration-per-line, quotes, prefer-template, prefer-arrow-callback, wrap-iife, max-len */
/* global IssuableIndex */
import _ from 'underscore';
import IssuableBulkUpdateSidebar from './issuable_bulk_update_sidebar';
import IssuableBulkUpdateActions from './issuable_bulk_update_actions';

((global) => {
  var issuable_created;

  issuable_created = false;

  global.IssuableIndex = {
    init: function(pagePrefix) {
      IssuableIndex.initTemplates();
      IssuableIndex.initSearch();
      IssuableIndex.initBulkUpdate(pagePrefix);
      IssuableIndex.initResetFilters();
      IssuableIndex.resetIncomingEmailToken();
      IssuableIndex.initLabelFilterRemove();
    },
    initTemplates: function() {
      return IssuableIndex.labelRow = _.template('<% _.each(labels, function(label){ %> <span class="label-row btn-group" role="group" aria-label="<%- label.title %>" style="color: <%- label.text_color %>;"> <a href="#" class="btn btn-transparent has-tooltip" style="background-color: <%- label.color %>;" title="<%- label.description %>" data-container="body"> <%- label.title %> </a> <button type="button" class="btn btn-transparent label-remove js-label-filter-remove" style="background-color: <%- label.color %>;" data-label="<%- label.title %>"> <i class="fa fa-times"></i> </button> </span> <% }); %>');
    },
    initSearch: function() {
      const $searchInput = $('#issuable_search');

      IssuableIndex.initSearchState($searchInput);

      // `immediate` param set to false debounces on the `trailing` edge, lets user finish typing
      const debouncedExecSearch = _.debounce(IssuableIndex.executeSearch, 1000, false);

      $searchInput.off('keyup').on('keyup', debouncedExecSearch);

      // ensures existing filters are preserved when manually submitted
      $('#issuable_search_form').on('submit', (e) => {
        e.preventDefault();
        debouncedExecSearch(e);
      });
    },
    initSearchState: function($searchInput) {
      const currentSearchVal = $searchInput.val();

      IssuableIndex.searchState = {
        elem: $searchInput,
        current: currentSearchVal
      };

      IssuableIndex.maybeFocusOnSearch();
    },
    accessSearchPristine: function(set) {
      // store reference to previous value to prevent search on non-mutating keyup
      const state = IssuableIndex.searchState;
      const currentSearchVal = state.elem.val();

      if (set) {
        state.current = currentSearchVal;
      } else {
        return state.current === currentSearchVal;
      }
    },
    maybeFocusOnSearch: function() {
      const currentSearchVal = IssuableIndex.searchState.current;
      if (currentSearchVal && currentSearchVal !== '') {
        const queryLength = currentSearchVal.length;
        const $searchInput = IssuableIndex.searchState.elem;

      /* The following ensures that the cursor is initially placed at
        * the end of search input when focus is applied. It accounts
        * for differences in browser implementations of `setSelectionRange`
        * and cursor placement for elements in focus.
      */
        $searchInput.focus();
        if ($searchInput.setSelectionRange) {
          $searchInput.setSelectionRange(queryLength, queryLength);
        } else {
          $searchInput.val(currentSearchVal);
        }
      }
    },
    executeSearch: function(e) {
      const $search = $('#issuable_search');
      const $searchName = $search.attr('name');
      const $searchValue = $search.val();
      const $filtersForm = $('.js-filter-form');
      const $input = $(`input[name='${$searchName}']`, $filtersForm);
      const isPristine = IssuableIndex.accessSearchPristine();

      if (isPristine) {
        return;
      }

      if (!$input.length) {
        $filtersForm.append(`<input type='hidden' name='${$searchName}' value='${_.escape($searchValue)}'/>`);
      } else {
        $input.val($searchValue);
      }

      IssuableIndex.filterResults($filtersForm);
    },
    initLabelFilterRemove: function() {
      return $(document).off('click', '.js-label-filter-remove').on('click', '.js-label-filter-remove', function(e) {
        var $button;
        $button = $(this);
        // Remove the label input box
        $('input[name="label_name[]"]').filter(function() {
          return this.value === $button.data('label');
        }).remove();
        // Submit the form to get new data
        IssuableIndex.filterResults($('.filter-form'));
      });
    },
    filterResults: (function(_this) {
      return function(form) {
        var formAction, formData, issuesUrl;
        formData = form.serializeArray();
        formData = formData.filter(function(data) {
          return data.value !== '';
        });
        formData = $.param(formData);
        formAction = form.attr('action');
        issuesUrl = formAction;
        issuesUrl += "" + (formAction.indexOf('?') === -1 ? '?' : '&');
        issuesUrl += formData;
        return gl.utils.visitUrl(issuesUrl);
      };
    })(this),
    initResetFilters: function() {
      $('.reset-filters').on('click', function(e) {
        e.preventDefault();
        const target = e.target;
        const $form = $(target).parents('.js-filter-form');
        const baseIssuesUrl = target.href;

        $form.attr('action', baseIssuesUrl);
        gl.utils.visitUrl(baseIssuesUrl);
      });
    },
    initBulkUpdate: function(pagePrefix) {
      const userCanBulkUpdate = $('.issues-bulk-update').length > 0;
      const alreadyInitialized = !!this.bulkUpdateSidebar;

      if (userCanBulkUpdate && !alreadyInitialized) {
        IssuableBulkUpdateActions.init({
          prefixId: pagePrefix,
        });

        this.bulkUpdateSidebar = new IssuableBulkUpdateSidebar();
      }
    },
    resetIncomingEmailToken: function() {
      $('.incoming-email-token-reset').on('click', function(e) {
        e.preventDefault();

        $.ajax({
          type: 'PUT',
          url: $('.incoming-email-token-reset').attr('href'),
          dataType: 'json',
          success: function(response) {
            $('#issue_email').val(response.new_issue_address).focus();
          },
          beforeSend: function() {
            $('.incoming-email-token-reset').text('resetting...');
          },
          complete: function() {
            $('.incoming-email-token-reset').text('reset it');
          }
        });
      });
    }
  };
})(window);
