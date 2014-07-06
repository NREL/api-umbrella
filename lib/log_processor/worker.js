'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    Convoy = require('redis-convoy'),
    elasticSearchConnect = require('../elasticsearch_connect'),
    events = require('events'),
    logCleaner = require('./cleaner'),
    logger = require('api-umbrella-gatekeeper').logger,
    moment = require('moment'),
    mongoConnect = require('../mongo_connect'),
    GatekeeperLogger = require('api-umbrella-gatekeeper').GatekeeperLogger,
    redis = require('redis'),
    url = require('url'),
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function() {
    this.apiKeyMethods = config.get('proxy.apiKeyMethods');
    async.parallel([
      mongoConnect,
      this.connectRedis.bind(this),
      this.connectElasticsearch.bind(this),
    ], this.handleConnections.bind(this));
  },

  connectRedis: function(asyncReadyCallback) {
    this.redis = redis.createClient(config.get('redis'));

    this.redis.on('error', function(error) {
      asyncReadyCallback(error);
    });

    this.redis.on('ready', function() {
      asyncReadyCallback(null);
    });
  },

  connectElasticsearch: function(asyncReadyCallback) {
    elasticSearchConnect(function(error, client) {
      this.elasticSearch = client;
      asyncReadyCallback(error);
    }.bind(this));
  },

  handleConnections: function(error) {
    if(error) {
      logger.error('Log processor worker connections error: ', error);
      process.exit(1);
      return false;
    }

    this.gatekeeperLogger = new GatekeeperLogger(this.redis);

    this.queue = Convoy.createQueue('log_queue');
    this.queue.process(this.processQueue.bind(this));

    this.fetchJobs();

    this.emit('ready');
  },

  fetchJobs: function() {
    this.gatekeeperLogger.fetchJobs(this.handleJobs.bind(this));
  },

  handleJobs: function(error, ids) {
    async.each(ids, function(id, asyncCallback) {
      // Push our log jobs onto the convoy queue. The convoy queue ensures
      // individual jobs will only get processed once, and allows multiple
      // worker processes to pull items off the queue (but it doesn't allow for
      // time delayed jobs, so that's why we have our own simplified
      // intermediate jobs).
      var job = new Convoy.Job(id);
      this.queue.addJob(job, function(error) {
        if(error && error !== 'committed') {
          asyncCallback(error);
          return false;
        }

        this.gatekeeperLogger.deleteJob(id, asyncCallback);
      }.bind(this));
    }.bind(this), function() {
      // Look for new log jobs again after all the current stack of jobs have
      // been pushed onto the convoy queue.
      setTimeout(this.fetchJobs.bind(this), 5000);
    }.bind(this));
  },

  processQueue: function(job, done) {
    this.gatekeeperLogger.fetchLog(job.id, this.handleLogFetch.bind(this, job.id, done));
  },

  handleLogFetch: function(id, done, error, log) {
    if(error) {
      done(error);
      return false;
    }

    // FIXME: This condition shouldn't happen, but it seemed to crop up and
    // cause terrible deaths when doing heavy load testing. It must be some
    // race condition, but this should be revisited. All of this logging
    // aggregation stuff could actually use a revisit and cleanup.
    if(!log) {
      logger.error('Log Fetch Error - No Log: ' + id);
      done(error);
      return false;
    }

    var combined = {};
    var data;

    if(log.proxy) {
      data = JSON.parse(log.proxy);
      _.extend(combined, data);
    }

    if(log.api_router) {
      data = JSON.parse(log.api_router);
      combined.backend_response_time = data.backend_response_time * 1000;
    }

    if(log.web_router) {
      data = JSON.parse(log.web_router);

      // Set certain stats that are most accurate from this front-most log (eg,
      // timers).
      _.extend(combined, {
        request_at: moment.unix(data.logged_at - data.response_time).toISOString(),
        response_status: data.response_status,
        response_size: data.response_size,
        request_size: data.request_size,
        response_time: data.response_time * 1000,
      });

      // For everything else, we'll prefer the log data coming from the
      // gatekeeper, but if it isn't present for some reason (eg, the
      // gatekeeper was down, or the user hit one of the higher nginx rate
      // limits), we'll still fill in what we can from the nginx logs.
      _.defaults(combined, {
        request_ip: data.request_ip,
        request_method: data.request_method,
        request_url: data.request_scheme + '://' + data.request_host + ':' + data.request_port + data.request_uri,
        request_user_agent: data.request_user_agent,
        request_referer: data.request_referer,
        request_basic_auth_username: data.request_basic_auth_username,
      });

      // Similarly, try to fill in the user information from the nginx logs if
      // the gatekeeper logs aren't present for some reason. This is probably
      // most relevant when the user is hitting the high nginx rate limits, in
      // which case we definitely want to know what user it was.
      if(!combined.api_key) {
        var apiKey;
        for(var i = 0, len = this.apiKeyMethods.length; i < len; i++) {
          switch(this.apiKeyMethods[i]) {
          case 'header':
            apiKey = data.request_api_key_header;
            break;
          case 'getParam':
            if(log.request_url) {
              var urlParts = url.parse(log.request_url, true);
              apiKey = urlParts.query.api_key;
            }

            break;
          case 'basicAuthUsername':
            apiKey = data.request_basic_auth_username;
            break;
          }

          if(apiKey) {
            break;
          }
        }

        if(apiKey) {
          combined.api_key = apiKey;
        }
      }

      if(combined.hasOwnProperty('backend_response_time')) {
        combined.proxy_overhead = data.backend_response_time * 1000 - combined.backend_response_time;
      }
    }

    var errorMessage;
    if(!combined.request_url) {
      errorMessage = 'Log data did not contain expected request_url field.';
    } else if(!combined.request_at) {
      errorMessage = 'Log data did not contain expected request_at field.';
    }

    if(errorMessage) {
      logger.error('Log data error: ', errorMessage);
      done(errorMessage);
    } else {
      logCleaner.all(this.elasticSearch, combined, this.handleLogCleaned.bind(this, id, done));
    }
  },

  handleLogCleaned: function(id, done, error, log) {
    var index = 'api-umbrella-logs-write-' + config.get('environment') + '-' + moment(log.request_at).utc().format('YYYY-MM');
    this.elasticSearch.index({
      index: index,
      type: 'log',
      id: id,
      body: log,
    }, this.handleLogIndexed.bind(this, id, done));
  },

  handleLogIndexed: function(id, done, error) {
    if(error) {
      logger.error('Index log error: ', error);
    } else {
      this.gatekeeperLogger.deleteLog(id);
    }

    done(error);
  },

  close: function(callback) {
    if(this.redis) {
      this.redis.quit();
    }

    if(callback) {
      callback(null);
    }
  },
});
