// Disable page animations when running in Capybara. This helps ensure the
// tests run more reliably and Capybara doesn't get confused about an element's
// visibility.
(function() {
  function ready() {
    // Disable all CSS animations and transitions.
    var styles = document.createElement('style');
    styles.type = 'text/css';
    styles.innerHTML = '* {' +
      '-webkit-transition: none !important;' +
      '-moz-transition: none !important;' +
      '-ms-transition: none !important;' +
      '-o-transition: none !important;' +
      'transition: none !important;' +
      '-webkit-transform: none !important;' +
      '-moz-transform: none !important;' +
      '-ms-transform: none !important;' +
      '-o-transform: none !important;' +
      'transform: none !important;' +
      '-webkit-animation: none !important;' +
      '-moz-animation: none !important;' +
      '-ms-animation: none !important;' +
      '-o-animation: none !important;' +
      'animation: none !important;' +
    '}';
    document.head.appendChild(styles);

    // If jQuery is being used, then also disable it's animations.
    if(window.jQuery) {
      window.jQuery.support.transition = false;
      window.jQuery.fx.off = true;
    }
  }

  // Setup now if document is already ready, or wait until document is ready.
  if(document.readyState === 'interactive' || document.readyState === 'complete') {
    ready();
  } else {
    document.addEventListener('DOMContentLoaded', ready);
  }
})();
