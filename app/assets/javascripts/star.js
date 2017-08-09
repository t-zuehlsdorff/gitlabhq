/* eslint-disable func-names, space-before-function-paren, wrap-iife, no-unused-vars, one-var, no-var, one-var-declaration-per-line, prefer-arrow-callback, no-new, max-len */
/* global Flash */

import { __, s__ } from './locale';

export default class Star {
  constructor() {
    $('.project-home-panel .toggle-star').on('ajax:success', function(e, data, status, xhr) {
      var $starIcon, $starSpan, $this, toggleStar;
      $this = $(this);
      $starSpan = $this.find('span');
      $starIcon = $this.find('i');
      toggleStar = function(isStarred) {
        $this.parent().find('.star-count').text(data.star_count);
        if (isStarred) {
          $starSpan.removeClass('starred').text(s__('StarProject|Star'));
          $starIcon.removeClass('fa-star').addClass('fa-star-o');
        } else {
          $starSpan.addClass('starred').text(__('Unstar'));
          $starIcon.removeClass('fa-star-o').addClass('fa-star');
        }
      };
      toggleStar($starSpan.hasClass('starred'));
    }).on('ajax:error', function(e, xhr, status, error) {
      new Flash('Star toggle failed. Try again later.', 'alert');
    });
  }
}
