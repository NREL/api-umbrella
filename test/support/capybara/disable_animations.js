window.onload = function() {
  var styles = document.createElement('style');
  styles.type = 'text/css';
  styles.innerHTML = '* {' +
    '-webkit-transition: none !important;' +
    '-moz-transition: none !important;' +
    '-ms-transition: none !important;' +
    '-o-transition: none !important;' +
    'transition: none !important;' +
  '}';
  document.head.appendChild(styles);
};

document.onload = function() {
  $.support.transition = false;
  $.fx.off = true;
};
