/* eslint no-param-reassign: "off" */

import GfmAutoComplete from '~/gfm_auto_complete';

import 'vendor/jquery.caret';
import 'vendor/jquery.atwho';

describe('GfmAutoComplete', function () {
  const gfmAutoCompleteCallbacks = GfmAutoComplete.prototype.getDefaultCallbacks.call({
    fetchData: () => {},
  });

  describe('DefaultOptions.sorter', function () {
    describe('assets loading', function () {
      beforeEach(function () {
        spyOn(GfmAutoComplete, 'isLoading').and.returnValue(true);

        this.atwhoInstance = { setting: {} };
        this.items = [];

        this.sorterValue = gfmAutoCompleteCallbacks.sorter
          .call(this.atwhoInstance, '', this.items);
      });

      it('should disable highlightFirst', function () {
        expect(this.atwhoInstance.setting.highlightFirst).toBe(false);
      });

      it('should return the passed unfiltered items', function () {
        expect(this.sorterValue).toEqual(this.items);
      });
    });

    describe('assets finished loading', function () {
      beforeEach(function () {
        spyOn(GfmAutoComplete, 'isLoading').and.returnValue(false);
        spyOn($.fn.atwho.default.callbacks, 'sorter');
      });

      it('should enable highlightFirst if alwaysHighlightFirst is set', function () {
        const atwhoInstance = { setting: { alwaysHighlightFirst: true } };

        gfmAutoCompleteCallbacks.sorter.call(atwhoInstance);

        expect(atwhoInstance.setting.highlightFirst).toBe(true);
      });

      it('should enable highlightFirst if a query is present', function () {
        const atwhoInstance = { setting: {} };

        gfmAutoCompleteCallbacks.sorter.call(atwhoInstance, 'query');

        expect(atwhoInstance.setting.highlightFirst).toBe(true);
      });

      it('should call the default atwho sorter', function () {
        const atwhoInstance = { setting: {} };

        const query = 'query';
        const items = [];
        const searchKey = 'searchKey';

        gfmAutoCompleteCallbacks.sorter.call(atwhoInstance, query, items, searchKey);

        expect($.fn.atwho.default.callbacks.sorter).toHaveBeenCalledWith(query, items, searchKey);
      });
    });
  });

  describe('DefaultOptions.matcher', function () {
    const defaultMatcher = (context, flag, subtext) => (
      gfmAutoCompleteCallbacks.matcher.call(context, flag, subtext)
    );

    const flagsUseDefaultMatcher = ['@', '#', '!', '~', '%'];
    const otherFlags = ['/', ':'];
    const flags = flagsUseDefaultMatcher.concat(otherFlags);

    const flagsHash = flags.reduce((hash, el) => { hash[el] = null; return hash; }, {});
    const atwhoInstance = { setting: {}, app: { controllers: flagsHash } };

    const minLen = 1;
    const maxLen = 20;
    const argumentSize = [minLen, maxLen / 2, maxLen];

    const allowedSymbols = ['', 'a', 'n', 'z', 'A', 'Z', 'N', '0', '5', '9', 'А', 'а', 'Я', 'я', '.', '\'', '+', '-', '_'];
    const jointAllowedSymbols = allowedSymbols.join('');

    describe('should match regular symbols', () => {
      flagsUseDefaultMatcher.forEach((flag) => {
        allowedSymbols.forEach((symbol) => {
          argumentSize.forEach((size) => {
            const query = new Array(size + 1).join(symbol);
            const subtext = flag + query;

            it(`matches argument "${flag}" with query "${subtext}"`, () => {
              expect(defaultMatcher(atwhoInstance, flag, subtext)).toBe(query);
            });
          });
        });

        it(`matches combination of allowed symbols for flag "${flag}"`, () => {
          const subtext = flag + jointAllowedSymbols;

          expect(defaultMatcher(atwhoInstance, flag, subtext)).toBe(jointAllowedSymbols);
        });
      });
    });

    describe('should not match special sequences', () => {
      const ShouldNotBeFollowedBy = flags.concat(['\x00', '\x10', '\x3f', '\n', ' ']);

      flagsUseDefaultMatcher.forEach((atSign) => {
        ShouldNotBeFollowedBy.forEach((followedSymbol) => {
          const seq = atSign + followedSymbol;

          it(`should not match "${seq}"`, () => {
            expect(defaultMatcher(atwhoInstance, atSign, seq)).toBe(null);
          });
        });
      });
    });
  });

  describe('isLoading', function () {
    it('should be true with loading data object item', function () {
      expect(GfmAutoComplete.isLoading({ name: 'loading' })).toBe(true);
    });

    it('should be true with loading data array', function () {
      expect(GfmAutoComplete.isLoading(['loading'])).toBe(true);
    });

    it('should be true with loading data object array', function () {
      expect(GfmAutoComplete.isLoading([{ name: 'loading' }])).toBe(true);
    });

    it('should be false with actual array data', function () {
      expect(GfmAutoComplete.isLoading([
        { title: 'Foo' },
        { title: 'Bar' },
        { title: 'Qux' },
      ])).toBe(false);
    });

    it('should be false with actual data item', function () {
      expect(GfmAutoComplete.isLoading({ title: 'Foo' })).toBe(false);
    });
  });
});
