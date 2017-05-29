/* eslint-disable space-before-function-paren, no-unused-expressions, no-return-assign, no-param-reassign, no-var, new-cap, wrap-iife, no-unused-vars, quotes, jasmine/no-expect-in-setup-teardown, max-len */
/* global Project */

import 'select2/select2';
import '~/gl_dropdown';
import '~/api';
import '~/project_select';
import '~/project';

(function() {
  describe('Project Title', function() {
    preloadFixtures('issues/open-issue.html.raw');
    loadJSONFixtures('projects.json');

    beforeEach(function() {
      loadFixtures('issues/open-issue.html.raw');

      window.gon = {};
      window.gon.api_version = 'v3';

      return this.project = new Project();
    });

    describe('project list', function() {
      var fakeAjaxResponse = function fakeAjaxResponse(req) {
        var d;
        expect(req.url).toBe('/api/v3/projects.json?simple=true');
        expect(req.data).toEqual({ search: '', order_by: 'last_activity_at', per_page: 20, membership: true });
        d = $.Deferred();
        d.resolve(this.projects_data);
        return d.promise();
      };

      beforeEach((function(_this) {
        return function() {
          _this.projects_data = getJSONFixture('projects.json');
          return spyOn(jQuery, 'ajax').and.callFake(fakeAjaxResponse.bind(_this));
        };
      })(this));
      it('toggles dropdown', function() {
        var menu = $('.js-dropdown-menu-projects');
        $('.js-projects-dropdown-toggle').click();
        expect(menu).toHaveClass('open');
        menu.find('.dropdown-menu-close-icon').click();
        expect(menu).not.toHaveClass('open');
      });
    });

    afterEach(() => {
      window.gon = {};
    });
  });
}).call(window);
