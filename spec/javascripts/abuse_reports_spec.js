import '~/lib/utils/text_utility';
import '~/abuse_reports';

((global) => {
  describe('Abuse Reports', () => {
    const FIXTURE = 'abuse_reports/abuse_reports_list.html.raw';
    const MAX_MESSAGE_LENGTH = 500;

    let $messages;

    const assertMaxLength = $message => expect($message.text().length).toEqual(MAX_MESSAGE_LENGTH);
    const findMessage = searchText => $messages.filter(
      (index, element) => element.innerText.indexOf(searchText) > -1,
    ).first();

    preloadFixtures(FIXTURE);

    beforeEach(function () {
      loadFixtures(FIXTURE);
      this.abuseReports = new global.AbuseReports();
      $messages = $('.abuse-reports .message');
    });

    it('should truncate long messages', () => {
      const $longMessage = findMessage('LONG MESSAGE');
      expect($longMessage.data('original-message')).toEqual(jasmine.anything());
      assertMaxLength($longMessage);
    });

    it('should not truncate short messages', () => {
      const $shortMessage = findMessage('SHORT MESSAGE');
      expect($shortMessage.data('original-message')).not.toEqual(jasmine.anything());
    });

    it('should allow clicking a truncated message to expand and collapse the full message', () => {
      const $longMessage = findMessage('LONG MESSAGE');
      $longMessage.click();
      expect($longMessage.data('original-message').length).toEqual($longMessage.text().length);
      $longMessage.click();
      assertMaxLength($longMessage);
    });
  });
})(window.gl);
