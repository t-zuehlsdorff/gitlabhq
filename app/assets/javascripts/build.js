/* eslint-disable func-names, wrap-iife, no-use-before-define,
consistent-return, prefer-rest-params */
/* global Breakpoints */

import _ from 'underscore';
import { bytesToKiB } from './lib/utils/number_utils';

window.Build = (function () {
  Build.timeout = null;
  Build.state = null;

  function Build(options) {
    this.options = options || $('.js-build-options').data();

    this.pageUrl = this.options.pageUrl;
    this.buildUrl = this.options.buildUrl;
    this.buildStatus = this.options.buildStatus;
    this.state = this.options.logState;
    this.buildStage = this.options.buildStage;
    this.$document = $(document);
    this.logBytes = 0;
    this.scrollOffsetPadding = 30;
    this.hasBeenScrolled = false;

    this.updateDropdown = this.updateDropdown.bind(this);
    this.getBuildTrace = this.getBuildTrace.bind(this);
    this.scrollToBottom = this.scrollToBottom.bind(this);

    this.$body = $('body');
    this.$buildTrace = $('#build-trace');
    this.$buildRefreshAnimation = $('.js-build-refresh');
    this.$truncatedInfo = $('.js-truncated-info');
    this.$buildTraceOutput = $('.js-build-output');
    this.$scrollContainer = $('.js-scroll-container');

    // Scroll controllers
    this.$scrollTopBtn = $('.js-scroll-up');
    this.$scrollBottomBtn = $('.js-scroll-down');

    clearTimeout(Build.timeout);
    // Init breakpoint checker
    this.bp = Breakpoints.get();

    this.initSidebar();
    this.populateJobs(this.buildStage);
    this.updateStageDropdownText(this.buildStage);
    this.sidebarOnResize();

    this.$document
      .off('click', '.js-sidebar-build-toggle')
      .on('click', '.js-sidebar-build-toggle', this.sidebarOnClick.bind(this));

    this.$document
      .off('click', '.stage-item')
      .on('click', '.stage-item', this.updateDropdown);

    // add event listeners to the scroll buttons
    this.$scrollTopBtn
      .off('click')
      .on('click', this.scrollToTop.bind(this));

    this.$scrollBottomBtn
      .off('click')
      .on('click', this.scrollToBottom.bind(this));

    const scrollThrottled = _.throttle(this.toggleScroll.bind(this), 100);

    this.$scrollContainer
      .off('scroll')
      .on('scroll', () => {
        this.hasBeenScrolled = true;
        scrollThrottled();
      });

    $(window)
      .off('resize.build')
      .on('resize.build', _.throttle(this.sidebarOnResize.bind(this), 100));

    this.updateArtifactRemoveDate();

    // eslint-disable-next-line
    this.getBuildTrace()
      .then(() => this.toggleScroll())
      .then(() => {
        if (!this.hasBeenScrolled) {
          this.scrollToBottom();
        }
      });

    this.verifyTopPosition();
  }

  Build.prototype.canScroll = function () {
    return (this.$scrollContainer.prop('scrollHeight') - this.scrollOffsetPadding) > this.$scrollContainer.height();
  };

  /**
   * |                          | Up       | Down     |
   * |--------------------------|----------|----------|
   * | on scroll bottom         | active   | disabled |
   * | on scroll top            | disabled | active   |
   * | no scroll                | disabled | disabled |
   * | on.('scroll') is on top  | disabled | active   |
   * | on('scroll) is on bottom | active   | disabled |
   *
   */
  Build.prototype.toggleScroll = function () {
    const currentPosition = this.$scrollContainer.scrollTop();
    const bottomScroll = currentPosition + this.$scrollContainer.innerHeight();

    if (this.canScroll()) {
      if (currentPosition === 0) {
        this.toggleDisableButton(this.$scrollTopBtn, true);
        this.toggleDisableButton(this.$scrollBottomBtn, false);
      } else if (bottomScroll === this.$scrollContainer.prop('scrollHeight')) {
        this.toggleDisableButton(this.$scrollTopBtn, false);
        this.toggleDisableButton(this.$scrollBottomBtn, true);
      } else {
        this.toggleDisableButton(this.$scrollTopBtn, false);
        this.toggleDisableButton(this.$scrollBottomBtn, false);
      }
    }
  };

  Build.prototype.scrollToTop = function () {
    this.hasBeenScrolled = true;
    this.$scrollContainer.scrollTop(0);
    this.toggleScroll();
  };

  Build.prototype.scrollToBottom = function () {
    this.hasBeenScrolled = true;
    this.$scrollContainer.scrollTop(this.$scrollContainer.prop('scrollHeight'));
    this.toggleScroll();
  };

  Build.prototype.toggleDisableButton = function ($button, disable) {
    if (disable && $button.prop('disabled')) return;
    $button.prop('disabled', disable);
  };

  Build.prototype.toggleScrollAnimation = function (toggle) {
    this.$scrollBottomBtn.toggleClass('animate', toggle);
  };

  /**
   * Build trace top position depends on the space ocupied by the elments rendered before
   */
  Build.prototype.verifyTopPosition = function () {
    const $buildPage = $('.build-page');

    const $flashError = $('.alert-wrapper');
    const $header = $('.build-header', $buildPage);
    const $runnersStuck = $('.js-build-stuck', $buildPage);
    const $startsEnvironment = $('.js-environment-container', $buildPage);
    const $erased = $('.js-build-erased', $buildPage);
    const prependTopDefault = 20;

    // header + navigation + margin
    let topPostion = 168;

    if ($header.length) {
      topPostion += $header.outerHeight();
    }

    if ($runnersStuck.length) {
      topPostion += $runnersStuck.outerHeight();
    }

    if ($startsEnvironment.length) {
      topPostion += $startsEnvironment.outerHeight() + prependTopDefault;
    }

    if ($erased.length) {
      topPostion += $erased.outerHeight() + prependTopDefault;
    }

    if ($flashError.length) {
      topPostion += $flashError.outerHeight();
    }

    this.$buildTrace.css({
      top: topPostion,
    });
  };

  Build.prototype.initSidebar = function () {
    this.$sidebar = $('.js-build-sidebar');
    this.$sidebar.niceScroll();
  };

  Build.prototype.getBuildTrace = function () {
    return $.ajax({
      url: `${this.pageUrl}/trace.json`,
      data: this.state,
    })
      .done((log) => {
        gl.utils.setCiStatusFavicon(`${this.pageUrl}/status.json`);
        if (log.state) {
          this.state = log.state;
        }

        if (log.append) {
          this.$buildTraceOutput.append(log.html);
          this.logBytes += log.size;
        } else {
          this.$buildTraceOutput.html(log.html);
          this.logBytes = log.size;
        }

        // if the incremental sum of logBytes we received is less than the total
        // we need to show a message warning the user about that.
        if (this.logBytes < log.total) {
          // size is in bytes, we need to calculate KiB
          const size = bytesToKiB(this.logBytes);
          $('.js-truncated-info-size').html(`${size}`);
          this.$truncatedInfo.removeClass('hidden');
        } else {
          this.$truncatedInfo.addClass('hidden');
        }

        if (!log.complete) {
          this.toggleScrollAnimation(true);

          Build.timeout = setTimeout(() => {
            //eslint-disable-next-line
            this.getBuildTrace()
              .then(() => {
                if (!this.hasBeenScrolled) {
                  this.scrollToBottom();
                }
              });
          }, 4000);
        } else {
          this.$buildRefreshAnimation.remove();
          this.toggleScrollAnimation(false);
        }

        if (log.status !== this.buildStatus) {
          gl.utils.visitUrl(this.pageUrl);
        }
      })
      .fail(() => {
        this.$buildRefreshAnimation.remove();
      });
  };

  Build.prototype.shouldHideSidebarForViewport = function () {
    const bootstrapBreakpoint = this.bp.getBreakpointSize();
    return bootstrapBreakpoint === 'xs' || bootstrapBreakpoint === 'sm';
  };

  Build.prototype.toggleSidebar = function (shouldHide) {
    const shouldShow = typeof shouldHide === 'boolean' ? !shouldHide : undefined;
    const $toggleButton = $('.js-sidebar-build-toggle-header');

    this.$buildTrace
      .toggleClass('sidebar-expanded', shouldShow)
      .toggleClass('sidebar-collapsed', shouldHide);
    this.$sidebar
      .toggleClass('right-sidebar-expanded', shouldShow)
      .toggleClass('right-sidebar-collapsed', shouldHide);

    $('.js-build-page')
      .toggleClass('sidebar-expanded', shouldShow)
      .toggleClass('sidebar-collapsed', shouldHide);

    if (this.$sidebar.hasClass('right-sidebar-expanded')) {
      $toggleButton.addClass('hidden');
    } else {
      $toggleButton.removeClass('hidden');
    }
  };

  Build.prototype.sidebarOnResize = function () {
    this.toggleSidebar(this.shouldHideSidebarForViewport());

    this.verifyTopPosition();

    if (this.canScroll()) {
      this.toggleScroll();
    }
  };

  Build.prototype.sidebarOnClick = function () {
    if (this.shouldHideSidebarForViewport()) this.toggleSidebar();
    this.verifyTopPosition();
  };

  Build.prototype.updateArtifactRemoveDate = function () {
    const $date = $('.js-artifacts-remove');
    if ($date.length) {
      const date = $date.text();
      return $date.text(
        gl.utils.timeFor(new Date(date.replace(/([0-9]+)-([0-9]+)-([0-9]+)/g, '$1/$2/$3')), ' '),
      );
    }
  };

  Build.prototype.populateJobs = function (stage) {
    $('.build-job').hide();
    $(`.build-job[data-stage="${stage}"]`).show();
  };

  Build.prototype.updateStageDropdownText = function (stage) {
    $('.stage-selection').text(stage);
  };

  Build.prototype.updateDropdown = function (e) {
    e.preventDefault();
    const stage = e.currentTarget.text;
    this.updateStageDropdownText(stage);
    this.populateJobs(stage);
  };

  return Build;
})();
