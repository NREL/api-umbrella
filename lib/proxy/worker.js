'use strict';

var _ = require('underscore'),
    async = require('async'),
    connect = require('connect'),
    connectBase = require('connect-base'),
    events = require('events'),
    http = require('http'),
    httpProxy = require('http-proxy'),
    i18n = require('i18n'),
    middleware = require('./middleware'),
    MongoClient = require('mongodb').MongoClient,
    ProxyLogger = require('./logger').Logger,
    redis = require('redis'),
    util = require('util');

i18n.configure({
  locales: ['en'],
  defaultLocale: 'en',
  updateFiles: false,
  directory: __dirname + '/../../locales'
});

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function(gatekeeper) {
    this.config = gatekeeper.config;

    async.parallel([
      this.connectMongo.bind(this),
      this.connectRedis.bind(this),
    ], this.handleConnections.bind(this));
  },

  connectMongo: function(asyncReadyCallback) {
    MongoClient.connect(this.config.get('mongodb'), this.handleConnectMongo.bind(this, asyncReadyCallback));
  },

  handleConnectMongo: function(asyncReadyCallback, error, db) {
    if(!error) {
      this.mongo = db;
      asyncReadyCallback(null);
    } else {
      asyncReadyCallback(error);
    }
  },

  connectRedis: function(asyncReadyCallback) {
    this.redis = redis.createClient(this.config.get('redis'));

    this.redis.on('error', function(error) {
      asyncReadyCallback(error);
    });

    this.redis.on('ready', function(error) {
      asyncReadyCallback(null);
    });
  },

  handleConnections: function(error, results) {
    if(error) {
      console.error(error);
      process.exit(1);
      return false;
    }

    this.proxyLogger = new ProxyLogger(this.redis);
    this.startServer();
    this.emit('ready');
  },

  startServer: function() {
    this.server = httpProxy
      .createServer(this.handleRequest.bind(this), {
        enable: {
          xforward: false,
        },
        changeOrigin: false,
      })
      .listen(this.config.get('proxy:port'), this.config.get('proxy:host'));

    this.server.proxy.on('start', this.handleProxyStart.bind(this));
    this.server.proxy.on('end', this.handleProxyEnd.bind(this));

    this.middlewares = [
      middleware.bufferRequest(),
      connectBase(),
      connect.query(),
      middleware.forwardedIp(this),
      middleware.apiKeyValidator(this),
      middleware.roleValdiator(this),
      middleware.rateLimit(this, this.config.get('proxy:rate_limits')),
      middleware.rewriteRequest(this),
      middleware.proxyBufferedRequest(this, this.server.proxy),
    ];

    this.stack = httpProxy.stack(this.middlewares, this.server.proxy);
  },

  handleRequest: function(request, response, proxy) {
    request.startTime = process.hrtime();
    request.startDate = new Date();

    this.startTime = process.hrtime();
    this.stack(request, response);
  },

  handleProxyStart: function(request, response) {
    request.gatekeeperTime = process.hrtime(request.startTime);
    request.proxyStartTime = process.hrtime();
  },

  handleProxyEnd: function(request, response) {
    var responseTime = process.hrtime(request.proxyStartTime);
    responseTime = responseTime[0] * 1000 + responseTime[1] / 1000000;

    var gatekeeperTime = request.gatekeeperTime[0] * 1000 + request.gatekeeperTime[1] / 1000000;

    var uid = request.headers['x-api-umbrella-uid'];
    var log = {
      request_at: request.startDate.toISOString(),
      request_method: request.method,
      request_url: request.base + request.url,
      request_user_agent: request.headers['user-agent'],
      request_accept_encoding: request.headers['accept-encoding'],
      request_content_type: request.headers['content-type'],
      request_origin: request.headers['origin'],
      request_ip: request.ip,
      response_status: response.statusCode,
      response_content_encoding: response.getHeader('content-encoding'),
      response_content_length: parseInt(response.getHeader('content-length'), 10),
      response_server: response.getHeader('server'),
      response_content_type: response.getHeader('content-type'),
      response_age: parseInt(response.getHeader('age'), 10),
      response_transfer_encoding: response.getHeader('transfer-encoding'),
      internal_gatekeeper_time: parseFloat(gatekeeperTime.toFixed(1)),
      internal_response_time: parseFloat(responseTime.toFixed(1)),
    };

    if(request.apiUmbrellaGatekeeper) {
      log.api_key = request.apiUmbrellaGatekeeper.apiKey;

      if(request.apiUmbrellaGatekeeper.user) {
        log.user_id = request.apiUmbrellaGatekeeper.user._id;
        log.user_email = request.apiUmbrellaGatekeeper.user.email;
      }
    }

    var data = JSON.stringify(log);
    this.proxyLogger.push(uid, 'proxy', data);
  },

  close: function(callback) {
    if(this.server) {
      this.server.close(callback);
    } else {
      callback(null);
    }
  },
});
