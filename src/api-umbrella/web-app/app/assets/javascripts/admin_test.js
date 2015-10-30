//= require jquery-simulate-ext/libs/jquery.simulate.js
//= require jquery-simulate-ext/src/jquery.simulate.ext.js
//= require jquery-simulate-ext/src/jquery.simulate.drag-n-drop.js

// Attempt to disable animations in test mode to improve the
// reliability of some Capybara timing stuff without sleeping:
// http://stackoverflow.com/a/13119950
// The other part of this is altering the CSS to disable transitions in
// admin_test.css.
$.support.transition = false;
$.fx.off = true;
$(document).ready(function() {
  $.support.transition = false;
  $.fx.off = true;
});
