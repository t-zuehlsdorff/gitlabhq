/* eslint-disable space-before-function-paren, one-var, one-var-declaration-per-line, no-use-before-define, comma-dangle, max-len */
import Issue from '~/issue';

import '~/lib/utils/text_utility';

describe('Issue', function() {
  let $boxClosed, $boxOpen, $btnClose, $btnReopen;

  preloadFixtures('issues/closed-issue.html.raw');
  preloadFixtures('issues/issue-with-task-list.html.raw');
  preloadFixtures('issues/open-issue.html.raw');

  function expectErrorMessage() {
    const $flashMessage = $('div.flash-alert');
    expect($flashMessage).toExist();
    expect($flashMessage).toBeVisible();
    expect($flashMessage).toHaveText('Unable to update this issue at this time.');
  }

  function expectIssueState(isIssueOpen) {
    expectVisibility($boxClosed, !isIssueOpen);
    expectVisibility($boxOpen, isIssueOpen);

    expectVisibility($btnClose, isIssueOpen);
    expectVisibility($btnReopen, !isIssueOpen);
  }

  function expectNewBranchButtonState(isPending, canCreate) {
    if (Issue.$btnNewBranch.length === 0) {
      return;
    }

    const $available = Issue.$btnNewBranch.find('.available');
    expect($available).toHaveText('New branch');

    if (!isPending && canCreate) {
      expect($available).toBeVisible();
    } else {
      expect($available).toBeHidden();
    }

    const $unavailable = Issue.$btnNewBranch.find('.unavailable');
    expect($unavailable).toHaveText('New branch unavailable');

    if (!isPending && !canCreate) {
      expect($unavailable).toBeVisible();
    } else {
      expect($unavailable).toBeHidden();
    }
  }

  function expectVisibility($element, shouldBeVisible) {
    if (shouldBeVisible) {
      expect($element).not.toHaveClass('hidden');
    } else {
      expect($element).toHaveClass('hidden');
    }
  }

  function findElements() {
    $boxClosed = $('div.status-box-closed');
    expect($boxClosed).toExist();
    expect($boxClosed).toHaveText('Closed');

    $boxOpen = $('div.status-box-open');
    expect($boxOpen).toExist();
    expect($boxOpen).toHaveText('Open');

    $btnClose = $('.btn-close.btn-grouped');
    expect($btnClose).toExist();
    expect($btnClose).toHaveText('Close issue');

    $btnReopen = $('.btn-reopen.btn-grouped');
    expect($btnReopen).toExist();
    expect($btnReopen).toHaveText('Reopen issue');
  }

  describe('task lists', function() {
    beforeEach(function() {
      loadFixtures('issues/issue-with-task-list.html.raw');
      this.issue = new Issue();
    });

    it('submits an ajax request on tasklist:changed', function() {
      spyOn(jQuery, 'ajax').and.callFake(function(req) {
        expect(req.type).toBe('PATCH');
        expect(req.url).toBe(gl.TEST_HOST + '/frontend-fixtures/issues-project/issues/1.json'); // eslint-disable-line prefer-template
        expect(req.data.issue.description).not.toBe(null);
      });

      $('.js-task-list-field').trigger('tasklist:changed');
    });
  });

  [true, false].forEach((isIssueInitiallyOpen) => {
    describe(`with ${isIssueInitiallyOpen ? 'open' : 'closed'} issue`, function() {
      const action = isIssueInitiallyOpen ? 'close' : 'reopen';

      function ajaxSpy(req) {
        if (req.url === this.$triggeredButton.attr('href')) {
          expect(req.type).toBe('PUT');
          expect(this.$triggeredButton).toHaveProp('disabled', true);
          expectNewBranchButtonState(true, false);
          return this.issueStateDeferred;
        } else if (req.url === Issue.createMrDropdownWrap.dataset.canCreatePath) {
          expect(req.type).toBe('GET');
          expectNewBranchButtonState(true, false);
          return this.canCreateBranchDeferred;
        }

        expect(req.url).toBe('unexpected');
        return null;
      }

      beforeEach(function() {
        if (isIssueInitiallyOpen) {
          loadFixtures('issues/open-issue.html.raw');
        } else {
          loadFixtures('issues/closed-issue.html.raw');
        }

        findElements();
        this.issue = new Issue();
        expectIssueState(isIssueInitiallyOpen);
        this.$triggeredButton = isIssueInitiallyOpen ? $btnClose : $btnReopen;

        this.$projectIssuesCounter = $('.issue_counter');
        this.$projectIssuesCounter.text('1,001');

        this.issueStateDeferred = new jQuery.Deferred();
        this.canCreateBranchDeferred = new jQuery.Deferred();

        spyOn(jQuery, 'ajax').and.callFake(ajaxSpy.bind(this));
      });

      it(`${action}s the issue`, function() {
        this.$triggeredButton.trigger('click');
        this.issueStateDeferred.resolve({
          id: 34
        });
        this.canCreateBranchDeferred.resolve({
          can_create_branch: !isIssueInitiallyOpen
        });

        expectIssueState(!isIssueInitiallyOpen);
        expect(this.$triggeredButton).toHaveProp('disabled', false);
        expect(this.$projectIssuesCounter.text()).toBe(isIssueInitiallyOpen ? '1,000' : '1,002');
        expectNewBranchButtonState(false, !isIssueInitiallyOpen);
      });

      it(`fails to ${action} the issue if saved:false`, function() {
        this.$triggeredButton.trigger('click');
        this.issueStateDeferred.resolve({
          saved: false
        });
        this.canCreateBranchDeferred.resolve({
          can_create_branch: isIssueInitiallyOpen
        });

        expectIssueState(isIssueInitiallyOpen);
        expect(this.$triggeredButton).toHaveProp('disabled', false);
        expectErrorMessage();
        expect(this.$projectIssuesCounter.text()).toBe('1,001');
        expectNewBranchButtonState(false, isIssueInitiallyOpen);
      });

      it(`fails to ${action} the issue if HTTP error occurs`, function() {
        this.$triggeredButton.trigger('click');
        this.issueStateDeferred.reject();
        this.canCreateBranchDeferred.resolve({
          can_create_branch: isIssueInitiallyOpen
        });

        expectIssueState(isIssueInitiallyOpen);
        expect(this.$triggeredButton).toHaveProp('disabled', true);
        expectErrorMessage();
        expect(this.$projectIssuesCounter.text()).toBe('1,001');
        expectNewBranchButtonState(false, isIssueInitiallyOpen);
      });

      it('disables the new branch button if Ajax call fails', function() {
        this.$triggeredButton.trigger('click');
        this.issueStateDeferred.reject();
        this.canCreateBranchDeferred.reject();

        expectNewBranchButtonState(false, false);
      });

      it('does not trigger Ajax call if new branch button is missing', function() {
        Issue.$btnNewBranch = $();
        this.canCreateBranchDeferred = null;

        this.$triggeredButton.trigger('click');
        this.issueStateDeferred.reject();
      });
    });
  });
});
