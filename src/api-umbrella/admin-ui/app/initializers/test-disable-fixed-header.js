import config from '../config/environment';

// Disable the fixed, floating header in the admin. This occasionally causes
// problems with Poltergeist's scroll logic, since Poltergeist thinks it's
// scrolled an element to click into view, but then it discovers there's the
// navbar overlapping it, making it unclickable.
function ready() {
  const style = document.createElement('style');
  style.type = 'text/css';
  style.innerHTML = 'body {' +
    'padding-top: 0px !important;' +
  '}' +
  '.fixed-top {' +
    'position: relative !important;' +
  '}';
  document.head.appendChild(style);
}

export function initialize() {
  if(config.integrationTestMode === true) {
    // Setup now if document is already ready, or wait until document is ready.
    if(document.readyState === 'interactive' || document.readyState === 'complete') {
      ready();
    } else {
      document.addEventListener('DOMContentLoaded', ready);
    }
  }
}

export default {
  name: 'test-disable-fixed-header',
  initialize,
};
