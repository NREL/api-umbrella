'use strict';

var querystring = require('querystring');

// Calls to url.parse(string, true), where query string parsing has been
// enabled can blow up when passed oddly encoded URLs. Requiring this file
// globally overrides the internal querystring.escape method to provide a
// non-exception throwing fallback to the original, unescaped string.
// querystring.escape's method is explicitly provided by the Node API in case
// the implementation needs to be overwritten, so this should be safe.
//
// See: https://github.com/joyent/node/issues/4247
querystring._origEscape = querystring.escape;
querystring.escape = function(str) {
  try {
    return querystring._origEscape.apply(querystring, arguments);
  } catch(e) {
    return str;
  }
};
