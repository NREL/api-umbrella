'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    connect = require('connect'),
    connectBase = require('connect-base'),
    events = require('events'),
    httpProxy = require('http-proxy'),
    logger = require('../logger'),
    middleware = require('./middleware'),
    mongoConnect = require('../mongo_connect'),
    mongoose = require('mongoose'),
    redis = require('redis'),
    simpleflake = require('simpleflake'),
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function(options) {
    this.options = options || {};

    async.parallel([
      this.connectMongo.bind(this),
      this.connectRedis.bind(this),
    ], this.handleConnections.bind(this));
  },

  connectMongo: function(asyncReadyCallback) {
    mongoConnect(asyncReadyCallback);
  },

  connectRedis: function(asyncReadyCallback) {
    var connected = false;
    this.redis = redis.createClient(config.get('redis.port'), config.get('redis.host'));

    this.redis.on('error', function(error) {
      logger.error('redis error: ', error);
      if(!connected) {
        asyncReadyCallback(error);
      }
    });

    this.redis.on('ready', function() {
      connected = true;
      asyncReadyCallback(null);
    });
  },

  handleConnections: function(error) {
    if(error) {
      logger.error('Gatekeeper worker connections error: ', error);
      process.exit(1);
      return false;
    }

    this.startServer();
  },

  startServer: function() {
    var port = this.options.port || config.get('gatekeeper.starting_port');
    this.server = httpProxy.createServer(this.handleRequest.bind(this), {
      enable: {
        xforward: false,
      },
      changeOrigin: false,
    });

    this.server.once('listening', function() {
      this.emit('ready');
    }.bind(this));

    this.server.on('error', function(error) {
      logger.error('Socket error: ', error);
    });

    this.server.proxy.on('start', this.handleProxyStart.bind(this));
    this.server.proxy.on('end', this.handleProxyEnd.bind(this));
    this.server.proxy.on('proxyError', this.handleProxyError.bind(this));

    this.middlewares = [
      middleware.bufferRequest(),
      connectBase(),
      connect.query(),
      middleware.forwardedIp(),
      middleware.basicAuth(),
      middleware.apiMatcher(),
      middleware.apiSettings(),
      middleware.apiKeyValidator(this),
      middleware.roleValdiator(this),
      middleware.ipValidator(this),
      middleware.refererValidator(this),
      middleware.rateLimit(this),
      middleware.rewriteRequest(),
      middleware.proxyBufferedRequest(this.server.proxy),
    ];

    this.stack = httpProxy.stack(this.middlewares, this.server.proxy);

    this.server.listen(port, config.get('gatekeeper.host'));
  },

  handleRequest: function(request, response) {
    request.startTime = process.hrtime();
    request.startDate = new Date();

    // If the gatekeeper returns an error response directly and never proxies,
    // http-proxy doesn't fire the normal proxy end event. So in those cases,
    // we fire our own 'deniedError' event to still handle wrapping up.
    response.on('deniedError', this.handleProxyDeniedError.bind(this, request, response));

    this.startTime = process.hrtime();
    this.stack(request, response);
  },

  handleProxyStart: function(request) {
    request.gatekeeperTime = process.hrtime(request.startTime);
    request.proxyStartTime = process.hrtime();
  },

  handleProxyDeniedError: function(request, response) {
    request.gatekeeperTime = process.hrtime(request.startTime);
    this.handleProxyEnd(request, response);
  },

  handleProxyEnd: function(request, response) {
    var responseTime;
    if(request.proxyStartTime) {
      responseTime = process.hrtime(request.proxyStartTime);
      responseTime = responseTime[0] * 1000 + responseTime[1] / 1000000;
    }

    var gatekeeperTime = request.gatekeeperTime[0] * 1000 + request.gatekeeperTime[1] / 1000000;

    var url;
    if(request.apiUmbrellaGatekeeper && request.apiUmbrellaGatekeeper.originalUrl) {
      url = request.apiUmbrellaGatekeeper.originalUrl;
    } else {
      url = request.url;
    }

    var log = {
      id: request.headers['x-api-umbrella-request-id'],
      source: 'gatekeeper',
      internal_gatekeeper_time: parseFloat(gatekeeperTime.toFixed(1)),

      // These fields aren't used for analytics purposes, but can be handy for
      // debugging purposes.
      req_at: request.startDate.toISOString(),
      req_url: request.base + url,
      res_status: response.statusCode,
    };

    if(responseTime) {
      log.internal_response_time = parseFloat(responseTime.toFixed(1));
    }

    if(request.apiUmbrellaGatekeeper) {
      log.api_key = request.apiUmbrellaGatekeeper.apiKey;

      if(request.apiUmbrellaGatekeeper.user) {
        log.user_id = request.apiUmbrellaGatekeeper.user._id;
        log.user_email = request.apiUmbrellaGatekeeper.user.email;
        log.user_registration_source = request.apiUmbrellaGatekeeper.user.registration_source;
      }
    }

    if(response.apiUmbrellaGatekeeper && response.apiUmbrellaGatekeeper.deniedCode) {
      log.gatekeeper_denied_code = response.apiUmbrellaGatekeeper.deniedCode;
    }

    var id = log.id;
    var source = 'gatekeeper';
    var data = JSON.stringify(log);

    if(!id) {
      id = simpleflake().toString('base58');
      if(process.env.NODE_ENV !== 'test') {
        logger.error('Missing unique request ID for logging. This should not occur. Make sure the "X-Api-Umbrella-Request-ID" HTTP header is present. Generated temporary ID', { temporaryId: id });
      }
    }

    this.redis.hset('log:' + id, source, data, function(error) {
      if(error) {
        logger.error('Failed to set redis log data', { id: id, source: source, data: data, error: error });
      }
    });
  },

  handleProxyError: function(error, request, response) {
    logger.error('Proxy error: ', error);

    if(!request.gatekeeperTime) {
      request.gatekeeperTime = process.hrtime(request.startTime);
    }

    this.handleProxyEnd(request, response);

    return false;
  },

  close: function(callback) {
    if(this.redis) {
      this.redis.quit();
    }

    if(mongoose.connection) {
      mongoose.connection.close();
    }

    if(this.server) {
      this.server.close(callback);
    } else if(callback) {
      callback(null);
    }
  },
});
