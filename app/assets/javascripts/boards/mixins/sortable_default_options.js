/* eslint-disable no-unused-vars, no-mixed-operators, comma-dangle */
/* global DocumentTouch */

window.gl = window.gl || {};
window.gl.issueBoards = window.gl.issueBoards || {};

gl.issueBoards.onStart = () => {
  $('.has-tooltip').tooltip('hide')
    .tooltip('disable');
  document.body.classList.add('is-dragging');
};

gl.issueBoards.onEnd = () => {
  $('.has-tooltip').tooltip('enable');
  document.body.classList.remove('is-dragging');
};

gl.issueBoards.touchEnabled = ('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch;

gl.issueBoards.getBoardSortableDefaultOptions = (obj) => {
  const defaultSortOptions = {
    animation: 200,
    forceFallback: true,
    fallbackClass: 'is-dragging',
    fallbackOnBody: true,
    ghostClass: 'is-ghost',
    filter: '.board-delete, .btn',
    delay: gl.issueBoards.touchEnabled ? 100 : 0,
    scrollSensitivity: gl.issueBoards.touchEnabled ? 60 : 100,
    scrollSpeed: 20,
    onStart: gl.issueBoards.onStart,
    onEnd: gl.issueBoards.onEnd
  };

  Object.keys(obj).forEach((key) => { defaultSortOptions[key] = obj[key]; });
  return defaultSortOptions;
};
