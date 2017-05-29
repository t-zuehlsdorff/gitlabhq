/* eslint-disable no-unused-expressions, no-prototype-builtins, no-new, no-shadow, max-len */

import 'vendor/jquery.endless-scroll';
import '~/pager';
import '~/activities';

(() => {
  window.gon || (window.gon = {});
  const fixtureTemplate = 'static/event_filter.html.raw';
  const filters = [
    {
      id: 'all',
    }, {
      id: 'push',
      name: 'push events',
    }, {
      id: 'merged',
      name: 'merge events',
    }, {
      id: 'comments',
    }, {
      id: 'team',
    }];

  function getEventName(index) {
    const filter = filters[index];
    return filter.hasOwnProperty('name') ? filter.name : filter.id;
  }

  function getSelector(index) {
    const filter = filters[index];
    return `#${filter.id}_event_filter`;
  }

  describe('Activities', () => {
    beforeEach(() => {
      loadFixtures(fixtureTemplate);
      new gl.Activities();
    });

    for (let i = 0; i < filters.length; i += 1) {
      ((i) => {
        describe(`when selecting ${getEventName(i)}`, () => {
          beforeEach(() => {
            $(getSelector(i)).click();
          });

          for (let x = 0; x < filters.length; x += 1) {
            ((x) => {
              const shouldHighlight = i === x;
              const testName = shouldHighlight ? 'should highlight' : 'should not highlight';

              it(`${testName} ${getEventName(x)}`, () => {
                expect($(getSelector(x)).parent().hasClass('active')).toEqual(shouldHighlight);
              });
            })(x);
          }
        });
      })(i);
    }
  });
})();
