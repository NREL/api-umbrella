var _ = require('underscore'),
    crypto = require('crypto'),
    dgram = require('dgram'),
    syslogParser = require('glossy').Parse,
    URLSafeBase64 = require('urlsafe-base64');

module.exports.createServer = function(gatekeeper) {
  return new HaproxyLogListener(gatekeeper);
}

var HaproxyLogListener = function() {
  this.initialize.apply(this, arguments);
}

_.extend(HaproxyLogListener.prototype, {
  initialize: function(gatekeeper) {
    this.gatekeeper = gatekeeper;
    this.redis = gatekeeper.redis;

    this.server = dgram.createSocket("udp4");
    this.server.on("message", this.handleMessage.bind(this));
    this.server.bind(this.gatekeeper.config.get('haproxy_log_listener:port'));
  },

  handleMessage: function(rawMessage) {
    var log = syslogParser.parse(rawMessage);
    var parts = log.message.split(' ');
    var frontend = parts[2];

    var uid = null;
    switch(frontend) {
      case "web_router":
        uid = parts[13];
        break;
      case "api_router":
        if(parts[14]) {
          var capturedHeaders = parts[14].replace(/(^{|}$)/g, '').split('|');
          uid = capturedHeaders[0];
        }
        break;
      default:
        console.info('UNEXPECTED LOG: ', log.message);
        break;
    }

    if(!uid || !uid.match(/[0-9A-Z]{40}$/)) {
      console.info('UNEXPECTED UID: ', uid);
    } else {
      console.info("UID: ", uid);
      var id = URLSafeBase64.encode(crypto.createHash('sha256').update(uid).digest('base64'));
      var processAt = Date.now() + 5 * 1000;

      this.redis.multi()
        .hset('log:' + id, frontend, log.message)
        .zadd('log_jobs', processAt, id)
        .exec();
    }
  },
});

