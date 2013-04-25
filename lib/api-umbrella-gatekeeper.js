var _ = require('underscore'),
    async = require('async'),
    crypto = require('crypto'),
    nconf = require('nconf'),
    connect = require('connect'),
    connectBase = require("connect-base");
    MongoClient = require('mongodb').MongoClient,
    redis = require('redis'),
    haproxyLogListener = require('./haproxy_log_listener'),
    http = require('http'),
    httpProxy = require('http-proxy'),
    logProcessor = require('./log_processor'),
    middleware = require('./middleware'),
    i18n = require('i18n'),
    URLSafeBase64 = require('urlsafe-base64');

i18n.configure({
    locales:['en', 'de'],
    defaultLocale: 'en',
    updateFiles: false,
    directory: __dirname + '/../locales'
    });

exports.createServer = function(config, readyCallback) {
  return new Server(config, readyCallback);
}

var Server = function() {
  this.initialize.apply(this, arguments);
}

_.extend(Server.prototype, {
  initialize: function(config, readyCallback) {
    this.initConfig(config);
    this.readyCallback = readyCallback;

    async.parallel([
      this.connectMongo.bind(this),
      this.connectRedis.bind(this),
    ], this.handleConnections.bind(this));
  },

  initConfig: function(config) {
    this.config = nconf;

    this.config.overrides(config);

    this.config.env();

    this.config.argv({
      'h': {
        alias: 'host',
        default: '0.0.0.0',
        describe: 'Hostname to bind to',
      },
      'p': {
        alias: 'port',
        default: '7890',
        describe: 'Port to lisen on',
      },
      't': {
        alias: 'target',
        default: '127.0.0.1:50100',
        describe: 'Backend server to proxy to',
      },
      'm': {
        alias: 'mongo',
        default: 'mongodb://127.0.0.1:27017/api_umbrella_development',
        describe: 'Mongo connection string',
      },
      'e': {
        alias: 'environment',
        default: 'development',
        describe: 'Framework environment',
      },
      'c': {
        alias: 'config',
        default: 'config/api_umbrella_gatekeeper.json',
        describe: 'Framework environment',
      },
    });

    this.config.file(this.config.get('config'));

    this.config.defaults({
      account_signup_uri: 'http://example.com/',
      contact_uri: 'http://example.com/contact',
      api_key_methods: [
        'header',
        'get_param',
        'basic_auth_username',
      ],
      trusted_proxies: ['127.0.0.1'],
      rate_limits: [
        {
          duration: 1 * 1000, // 1 second
          accuracy: 500, // 500 milliseconds
          limit_by: 'ip',
          limit: 250000,
          distributed: false,
        }, {
          duration: 1 * 1000, // 1 second
          accuracy: 500, // 500 milliseconds
          limit_by: 'api_key',
          limit: 150000,
          distributed: false,
        }, {
          duration: 60 * 60 * 1000, // 1 hour
          accuracy: 1 * 60 * 1000, // 1 minute
          limit_by: 'api_key',
          limit: 10000000,
          distributed: true,
        }
      ],
      haproxy_log_listener: {
        port: 5114,
      }
    });
  },

  connectMongo: function(asyncReadyCallback) {
    MongoClient.connect(this.config.get('mongo'), this.handleConnectMongo.bind(this, asyncReadyCallback));
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
    this.redis = redis.createClient('/tmp/redis.sock');

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
    } else {
      this.startHaproxyLogListener();
      this.startLogProcessor();
      this.startServer();
    }
  },

  startHaproxyLogListener: function() {
    this.haproxyLogListener = haproxyLogListener.createServer(this);
  },

  startLogProcessor: function() {
    this.logProcessor = logProcessor.process(this);
  },

  startServer: function() {
    this.server = httpProxy
      .createServer(this.handleRequest.bind(this), {
        enable: {
          xforward: false,
        },
        changeOrigin: false,
      })
      .listen(this.config.get('port'), this.config.get('host'));

    this.server.proxy.on('start', this.handleProxyStart.bind(this));
    this.server.proxy.on('end', this.handleProxyEnd.bind(this));

    this.middlewares = [
      middleware.bufferRequest(),
      connectBase(),
      connect.query(),
      middleware.forwardedIp(this),
      middleware.apiKeyValidator(this),
      middleware.roleValdiator(this),
      middleware.rateLimit(this, this.config.get('rate_limits')),
      middleware.proxyBufferedRequest(this, this.server.proxy),
    ];

    this.stack = httpProxy.stack(this.middlewares, this.server.proxy);

    if(this.readyCallback) {
      this.readyCallback();
    }
  },

  handleRequest: function(request, response, proxy) {
    request.startTime = process.hrtime();

    this.startTime = process.hrtime();
    this.stack(request, response);
  },

  handleProxyStart: function(request, response) {
    request.gatekeeperTime = process.hrtime(request.startTime);
    request.proxyStartTime = process.hrtime();
  },

  handleProxyEnd: function(request, response) {
    var gatekeeperTime = request.gatekeeperTime[0] * 1000 + request.gatekeeperTime[1] / 1000000;

    var responseTime = process.hrtime(request.proxyStartTime);
    responseTime = responseTime[0] * 1000 + responseTime[1] / 1000000;

    var uid = request.headers['x-apiumbrella-uid'];
    if(!uid) {
      uid = Date.now().toString() + '-' + Math.random().toString();
    }

    var id = URLSafeBase64.encode(crypto.createHash('sha256').update(uid).digest('base64'));

    var log = {
      request_method: request.method,
      request_url: request.base + request.url,
      request_user_agent: request.headers['user-agent'],
      request_accept_encoding: request.headers['accept-encoding'],
      request_content_type: request.headers['content-type'],
      request_origin: request.headers['origin'],
      request_ip: request.ip,
      response_status: response.statusCode,
      response_content_encoding: response.getHeader('content-encoding'),
      response_content_length: response.getHeader('content-length'),
      response_server: response.getHeader('server'),
      response_content_type: response.getHeader('content-type'),
      response_transfer_encoding: response.getHeader('transfer-encoding'),
      internal_gatekeeper_time: gatekeeperTime,
      internal_response_time: responseTime,
    }

    if(request.apiUmbrellaGatekeeper) {
      log.api_key = request.apiUmbrellaGatekeeper.apiKey
    }

    var processAt = Date.now() + 30 * 60 * 1000;
    var data = JSON.stringify(log);

    this.redis.multi()
      .hset('log:' + id, 'proxy', data)
      .zadd('log_jobs', processAt, id)
      .exec();
  },

  close: function(callback) {
    if(this.server) {
      this.server.close(callback);
    }
  },
});
