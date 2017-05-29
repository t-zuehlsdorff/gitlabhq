/* global Flash */

import BalsamiqViewer from './balsamiq/balsamiq_viewer';

function onError() {
  const flash = new window.Flash('Balsamiq file could not be loaded.');

  return flash;
}

function loadBalsamiqFile() {
  const viewer = document.getElementById('js-balsamiq-viewer');

  if (!(viewer instanceof Element)) return;

  const endpoint = viewer.dataset.endpoint;

  const balsamiqViewer = new BalsamiqViewer(viewer);
  balsamiqViewer.loadFile(endpoint).catch(onError);
}

$(loadBalsamiqFile);
