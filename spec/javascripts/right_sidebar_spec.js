/* eslint-disable space-before-function-paren, no-var, one-var, one-var-declaration-per-line, new-parens, no-return-assign, new-cap, vars-on-top, max-len */
/* global Sidebar */

import '~/commons/bootstrap';
import '~/right_sidebar';

(function() {
  var $aside, $icon, $labelsIcon, $page, $toggle, assertSidebarState;

  this.sidebar = null;

  $aside = null;

  $toggle = null;

  $icon = null;

  $page = null;

  $labelsIcon = null;

  assertSidebarState = function(state) {
    var shouldBeCollapsed, shouldBeExpanded;
    shouldBeExpanded = state === 'expanded';
    shouldBeCollapsed = state === 'collapsed';
    expect($aside.hasClass('right-sidebar-expanded')).toBe(shouldBeExpanded);
    expect($page.hasClass('right-sidebar-expanded')).toBe(shouldBeExpanded);
    expect($icon.hasClass('fa-angle-double-right')).toBe(shouldBeExpanded);
    expect($aside.hasClass('right-sidebar-collapsed')).toBe(shouldBeCollapsed);
    expect($page.hasClass('right-sidebar-collapsed')).toBe(shouldBeCollapsed);
    return expect($icon.hasClass('fa-angle-double-left')).toBe(shouldBeCollapsed);
  };

  describe('RightSidebar', function() {
    var fixtureName = 'issues/open-issue.html.raw';
    preloadFixtures(fixtureName);
    loadJSONFixtures('todos/todos.json');

    beforeEach(function() {
      loadFixtures(fixtureName);
      this.sidebar = new Sidebar;
      $aside = $('.right-sidebar');
      $page = $('.page-with-sidebar');
      $icon = $aside.find('i');
      $toggle = $aside.find('.js-sidebar-toggle');
      return $labelsIcon = $aside.find('.sidebar-collapsed-icon');
    });
    it('should expand/collapse the sidebar when arrow is clicked', function() {
      assertSidebarState('expanded');
      $toggle.click();
      assertSidebarState('collapsed');
      $toggle.click();
      assertSidebarState('expanded');
    });
    it('should float over the page and when sidebar icons clicked', function() {
      $labelsIcon.click();
      return assertSidebarState('expanded');
    });
    it('should collapse when the icon arrow clicked while it is floating on page', function() {
      $labelsIcon.click();
      assertSidebarState('expanded');
      $toggle.click();
      return assertSidebarState('collapsed');
    });

    it('should broadcast todo:toggle event when add todo clicked', function() {
      var todos = getJSONFixture('todos/todos.json');
      spyOn(jQuery, 'ajax').and.callFake(function() {
        var d = $.Deferred();
        var response = todos;
        d.resolve(response);
        return d.promise();
      });

      var todoToggleSpy = spyOnEvent(document, 'todo:toggle');

      $('.issuable-sidebar-header .js-issuable-todo').click();

      expect(todoToggleSpy.calls.count()).toEqual(1);
    });

    it('should not hide collapsed icons', () => {
      [].forEach.call(document.querySelectorAll('.sidebar-collapsed-icon'), (el) => {
        expect(el.querySelector('.fa, svg').classList.contains('hidden')).toBeFalsy();
      });
    });
  });
}).call(window);
