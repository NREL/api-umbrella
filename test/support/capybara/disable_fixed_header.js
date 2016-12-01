// Disable the fixed, floating header in the admin. This occasionally causes
// problems with Poltergeist's scroll logic, since Poltergeist thinks it's
// scrolled an element to click into view, but then it discovers there's the
// navbar overlapping it, making it unclickable.
(function() {
  function ready() {
    var styles = document.createElement('style');
    styles.type = 'text/css';
    styles.innerHTML = 'body {' +
      'padding-top: 0px !important;' +
    '}' +
    '.navbar-fixed-top {' +
      'position: relative !important;' +
    '}';
    document.head.appendChild(styles);
  }

  // Setup now if document is already ready, or wait until document is ready.
  if(document.readyState === 'interactive' || document.readyState === 'complete') {
    ready();
  } else {
    document.addEventListener('DOMContentLoaded', ready);
  }
})();
