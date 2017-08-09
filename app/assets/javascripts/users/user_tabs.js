import ActivityCalendar from './activity_calendar';

/**
 * UserTabs
 *
 * Handles persisting and restoring the current tab selection and lazily-loading
 * content on the Users#show page.
 *
 * ### Example Markup
 *
 * <ul class="nav-links">
 *   <li class="activity-tab active">
 *     <a data-action="activity" data-target="#activity" data-toggle="tab" href="/u/username">
 *       Activity
 *     </a>
 *   </li>
 *   <li class="groups-tab">
 *     <a data-action="groups" data-target="#groups" data-toggle="tab" href="/u/username/groups">
 *       Groups
 *     </a>
 *   </li>
 *   <li class="contributed-tab">
 *     ...
 *   </li>
 *   <li class="projects-tab">
 *     ...
 *   </li>
 *   <li class="snippets-tab">
 *     ...
 *   </li>
 * </ul>
 *
 * <div class="tab-content">
 *   <div class="tab-pane" id="activity">
 *     Activity Content
 *   </div>
 *   <div class="tab-pane" id="groups">
 *     Groups Content
 *   </div>
 *   <div class="tab-pane" id="contributed">
 *     Contributed projects content
 *   </div>
 *   <div class="tab-pane" id="projects">
 *    Projects content
 *   </div>
 *   <div class="tab-pane" id="snippets">
 *     Snippets content
 *   </div>
 * </div>
 *
 * <div class="loading-status">
 *   <div class="loading">
 *     Loading Animation
 *   </div>
 * </div>
 */

const CALENDAR_TEMPLATE = `
  <div class="clearfix calendar">
    <div class="js-contrib-calendar"></div>
    <div class="calendar-hint">
      Summary of issues, merge requests, push events, and comments
    </div>
  </div>
`;

export default class UserTabs {
  constructor({ defaultAction, action, parentEl }) {
    this.loaded = {};
    this.defaultAction = defaultAction || 'activity';
    this.action = action || this.defaultAction;
    this.$parentEl = $(parentEl) || $(document);
    this.windowLocation = window.location;
    this.$parentEl.find('.nav-links a')
      .each((i, navLink) => {
        this.loaded[$(navLink).attr('data-action')] = false;
      });
    this.actions = Object.keys(this.loaded);
    this.bindEvents();

    if (this.action === 'show') {
      this.action = this.defaultAction;
    }

    this.activateTab(this.action);
  }

  bindEvents() {
    this.$parentEl
      .off('shown.bs.tab', '.nav-links a[data-toggle="tab"]')
      .on('shown.bs.tab', '.nav-links a[data-toggle="tab"]', event => this.tabShown(event))
      .on('click', '.gl-pagination a', event => this.changeProjectsPage(event));
  }

  changeProjectsPage(e) {
    e.preventDefault();

    $('.tab-pane.active').empty();
    const endpoint = $(e.target).attr('href');
    this.loadTab(this.getCurrentAction(), endpoint);
  }

  tabShown(event) {
    const $target = $(event.target);
    const action = $target.data('action');
    const source = $target.attr('href');
    const endpoint = $target.data('endpoint');
    this.setTab(action, endpoint);
    return this.setCurrentAction(source);
  }

  activateTab(action) {
    return this.$parentEl.find(`.nav-links .js-${action}-tab a`)
      .tab('show');
  }

  setTab(action, endpoint) {
    if (this.loaded[action]) {
      return;
    }
    if (action === 'activity') {
      this.loadActivities();
    }

    const loadableActions = ['groups', 'contributed', 'projects', 'snippets'];
    if (loadableActions.indexOf(action) > -1) {
      this.loadTab(action, endpoint);
    }
  }

  loadTab(action, endpoint) {
    return $.ajax({
      beforeSend: () => this.toggleLoading(true),
      complete: () => this.toggleLoading(false),
      dataType: 'json',
      url: endpoint,
      success: (data) => {
        const tabSelector = `div#${action}`;
        this.$parentEl.find(tabSelector).html(data.html);
        this.loaded[action] = true;
        gl.utils.localTimeAgo($('.js-timeago', tabSelector));
      },
    });
  }

  loadActivities() {
    if (this.loaded.activity) {
      return;
    }
    const $calendarWrap = this.$parentEl.find('.user-calendar');
    const calendarPath = $calendarWrap.data('calendarPath');
    const calendarActivitiesPath = $calendarWrap.data('calendarActivitiesPath');
    const utcOffset = $calendarWrap.data('utcOffset');
    let utcFormatted = 'UTC';
    if (utcOffset !== 0) {
      utcFormatted = `UTC${utcOffset > 0 ? '+' : ''}${(utcOffset / 3600)}`;
    }

    $.ajax({
      dataType: 'json',
      url: calendarPath,
      success: (activityData) => {
        $calendarWrap.html(CALENDAR_TEMPLATE);
        $calendarWrap.find('.calendar-hint').append(`(Timezone: ${utcFormatted})`);

        // eslint-disable-next-line no-new
        new ActivityCalendar('.js-contrib-calendar', activityData, calendarActivitiesPath, utcOffset);
      },
    });

    // eslint-disable-next-line no-new
    new gl.Activities();
    this.loaded.activity = true;
  }

  toggleLoading(status) {
    return this.$parentEl.find('.loading-status .loading')
      .toggle(status);
  }

  setCurrentAction(source) {
    let newState = source;
    newState = newState.replace(/\/+$/, '');
    newState += this.windowLocation.search + this.windowLocation.hash;
    history.replaceState({
      url: newState,
    }, document.title, newState);
    return newState;
  }

  getCurrentAction() {
    return this.$parentEl.find('.nav-links .active a').data('action');
  }
}
