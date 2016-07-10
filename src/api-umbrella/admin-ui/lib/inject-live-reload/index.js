/*jshint node:true*/

// Copy of ember-cli-inject-live-reload, but customized to allow for proxying
// behind HTTPS.
//
// Copied as of this commit:
// https://github.com/rwjblue/ember-cli-inject-live-reload/blob/bf144a1c417cd6700f177ee92424dec7b7f53b73/index.js
module.exports = {
  name: 'live-reload',

  contentFor: function(type) {
    var liveReloadPort = process.env.EMBER_CLI_INJECT_LIVE_RELOAD_PORT;
    var baseURL = process.env.EMBER_CLI_INJECT_LIVE_RELOAD_BASEURL;

    if (liveReloadPort && type === 'head') {
      return '<script src="' + baseURL + 'ember-cli-live-reload.js" type="text/javascript"></script>';
    }
  },

  dynamicScript: function(request) {
    var liveReloadPort = process.env.EMBER_CLI_INJECT_LIVE_RELOAD_PORT;

    return "(function() {\n " +
           "var src = (location.protocol || 'http:') + '//' + (location.hostname || 'localhost') + ':" + liveReloadPort + "/livereload.js?snipver=1&port=" + liveReloadPort + "';\n " +
           "var script    = document.createElement('script');\n " +
           "script.type   = 'text/javascript';\n " +
           "script.src    = src;\n " +
           "document.getElementsByTagName('head')[0].appendChild(script);\n" +
           "}());";
  },

  serverMiddleware: function(config) {
    var self = this;
    var app = config.app;
    var options = config.options;

    if (options.liveReload !== true) { return; }

    if(!process.env.EMBER_CLI_INJECT_LIVE_RELOAD_PORT) {
      process.env.EMBER_CLI_INJECT_LIVE_RELOAD_PORT = options.liveReloadPort;
    }
    process.env.EMBER_CLI_INJECT_LIVE_RELOAD_BASEURL = options.liveReloadBaseUrl || options.baseURL;

    app.use(options.baseURL + 'ember-cli-live-reload.js', function(request, response, next) {
      response.contentType('text/javascript');
      response.send(self.dynamicScript());
    });
  }
};
