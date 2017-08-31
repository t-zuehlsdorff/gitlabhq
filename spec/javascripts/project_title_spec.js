/* global Project */

import 'select2/select2';
import '~/gl_dropdown';
import '~/api';
import '~/project_select';
import '~/project';

describe('Project Title', () => {
  const dummyApiVersion = 'v3000';
  preloadFixtures('issues/open-issue.html.raw');
  loadJSONFixtures('projects.json');

  beforeEach(() => {
    loadFixtures('issues/open-issue.html.raw');

    window.gon = {};
    window.gon.api_version = dummyApiVersion;

    // eslint-disable-next-line no-new
    new Project();
  });

  describe('project list', () => {
    let reqUrl;
    let reqData;

    beforeEach(() => {
      const fakeResponseData = getJSONFixture('projects.json');
      spyOn(jQuery, 'ajax').and.callFake((req) => {
        const def = $.Deferred();
        reqUrl = req.url;
        reqData = req.data;
        def.resolve(fakeResponseData);
        return def.promise();
      });
    });

    it('toggles dropdown', () => {
      const $menu = $('.js-dropdown-menu-projects');
      window.gon.current_user_id = 1;
      $('.js-projects-dropdown-toggle').click();
      expect($menu).toHaveClass('open');
      expect(reqUrl).toBe(`/api/${dummyApiVersion}/projects.json?simple=true`);
      expect(reqData).toEqual({
        search: '',
        order_by: 'last_activity_at',
        per_page: 20,
        membership: true,
      });
      $menu.find('.dropdown-menu-close-icon').click();
      expect($menu).not.toHaveClass('open');
    });
  });

  afterEach(() => {
    window.gon = {};
  });
});
