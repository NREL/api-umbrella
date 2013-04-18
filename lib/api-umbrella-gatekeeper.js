var _ = require('underscore'),
    async = require('async'),
    nconf = require('nconf'),
    connect = require('connect'),
    MongoClient = require('mongodb').MongoClient,
    redis = require('redis'),
    http = require('http'),
    httpProxy = require('http-proxy'),
    middleware = require('./middleware'),
    i18n = require('i18n');

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
      _.bind(this.connectMongo, this),
      _.bind(this.connectRedis, this),
    ], _.bind(this.handleConnections, this));
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
          limit: 25,
          distributed: false,
        }, {
          duration: 1 * 1000, // 1 second
          accuracy: 500, // 500 milliseconds
          limit_by: 'api_key',
          limit: 15,
          distributed: false,
        }, {
          duration: 60 * 60 * 1000, // 1 hour
          accuracy: 1 * 60 * 1000, // 1 minute
          limit_by: 'api_key',
          limit: 1000,
          distributed: true,
        }
      ],
    });
  },

  connectMongo: function(asyncReadyCallback) {
    MongoClient.connect(this.config.get('mongo'), _.bind(this.handleConnectMongo, this, asyncReadyCallback));
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
    this.redis = redis.createClient();

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
      this.startServer();
    }
  },

  startServer: function() {
    var middlewares = [
      middleware.bufferRequest(),
      connect.query(),
      middleware.forwardedIp(this),
      middleware.apiKeyValidator(this),
      middleware.roleValdiator(this),
      middleware.rateLimit(this, this.config.get('rate_limits')),
    ];

    this.server = httpProxy.createServer(function(request, response, proxy) {
      var buffer = httpProxy.buffer(request);

      var requestMiddlewares = middlewares.concat([
        middleware.proxyBufferedRequest(this, proxy),
      ]);

      var stack = httpProxy.stack(requestMiddlewares, proxy);
      stack(request, response);
    }.bind(this)).listen(this.config.get('port'), this.config.get('host'));

    if(this.readyCallback) {
      this.readyCallback();
    }
  },

  close: function(callback) {
    if(this.server) {
      this.server.close(callback);
    }
  },
});
