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
    ProxyLogger = require('./logger').Logger,
    redis = require('redis'),
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
    this.redis = redis.createClient(config.get('redis.port'), config.get('redis.host'));

    this.redis.on('error', function(error) {
      asyncReadyCallback(error);
    });

    this.redis.on('ready', function() {
      asyncReadyCallback(null);
    });
  },

  handleConnections: function(error) {
    if(error) {
      logger.error('Gatekeeper worker connections error: ', error);
      process.exit(1);
      return false;
    }

    this.proxyLogger = new ProxyLogger(this.redis);
    this.startServer();
    this.emit('ready');
  },

  startServer: function() {
    var port = this.options.port || config.get('proxy.port');
    this.server = httpProxy
      .createServer(this.handleRequest.bind(this), {
        enable: {
          xforward: false,
        },
        changeOrigin: false,
      })
      .listen(port, config.get('proxy.host'));

    this.server.proxy.on('start', this.handleProxyStart.bind(this));
    this.server.proxy.on('end', this.handleProxyEnd.bind(this));

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
  },

  handleRequest: function(request, response) {
    request.startTime = process.hrtime();
    request.startDate = new Date();

    // If the gatekeeper returns an error response directly and never proxies,
    // http-proxy doesn't fire the normal proxy end event. So in those cases,
    // we fire our own 'endError' event to still handle wrapping up.
    response.on('endError', this.handleProxyEndError.bind(this, request, response));

    this.startTime = process.hrtime();
    this.stack(request, response);
  },

  handleProxyStart: function(request) {
    request.gatekeeperTime = process.hrtime(request.startTime);
    request.proxyStartTime = process.hrtime();
  },

  handleProxyEndError: function(request, response) {
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

    var uid = request.headers['x-api-umbrella-uid'];
    var log = {
      request_at: request.startDate.toISOString(),
      request_method: request.method,
      request_url: request.base + url,
      request_user_agent: request.headers['user-agent'],
      request_accept: request.headers.accept,
      request_accept_encoding: request.headers['accept-encoding'],
      request_connection: request.headers.connection,
      request_content_type: request.headers['content-type'],
      request_origin: request.headers.origin,
      request_referer: request.headers.referer,
      request_basic_auth_username: request.basicAuthUsername,
      request_ip: request.ip,
      response_status: response.statusCode,
      response_content_encoding: response.getHeader('content-encoding'),
      response_content_length: parseInt(response.getHeader('content-length'), 10),
      response_server: response.getHeader('server'),
      response_content_type: response.getHeader('content-type'),
      response_age: parseInt(response.getHeader('age'), 10),
      response_transfer_encoding: response.getHeader('transfer-encoding'),
      internal_gatekeeper_time: parseFloat(gatekeeperTime.toFixed(1)),
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

    var data = JSON.stringify(log);
    this.proxyLogger.push(uid, 'proxy', data);
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
