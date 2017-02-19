module.exports = {
  name: 'inject-live-reload-config',

  // Define the config for live-reload so it's always based on the current URL.
  //
  // In combination with the .ember-cli "liveReloadJsUrl" config, this takes
  // into account the HTTPS proxy that's in front of the ember development
  // server.
  contentFor(type) {
    let liveReloadPort = process.env.EMBER_CLI_INJECT_LIVE_RELOAD_PORT;
    if(liveReloadPort && type === 'head') {
      return '<script type="text/javascript">\n' +
        '  window.LiveReloadOptions = {\n' +
        '    https: (location.protocol === \'https:\'),\n' +
        '    host: location.hostname,\n' +
        '    port: (location.port) ? location.port : ((location.protocol === \'https:\') ? 443 : 80)\n' +
        '  };\n' +
        '</script>';
    }
  },
};
