'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    elasticSearchConnect = require('../elasticsearch_connect'),
    events = require('events'),
    fivebeans = require('fivebeans'),
    logCleaner = require('./cleaner'),
    logger = require('../logger'),
    moment = require('moment'),
    mongoConnect = require('../mongo_connect'),
    redis = require('redis'),
    util = require('util');

// Ensure that url.parse(str, true) gets handled safely anywhere subsequently
// in this app.
require('api-umbrella-gatekeeper/lib/safe_url_parse');

var Worker = function() {
  this.initialize.apply(this, arguments);
};

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function() {
    this.apiKeyMethods = config.get('gatekeeper.api_key_methods');
    async.parallel([
      mongoConnect,
      this.connectRedis.bind(this),
      this.connectElasticsearch.bind(this),
      this.connectBeanstalk.bind(this),
    ], this.handleConnections.bind(this));
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

  connectElasticsearch: function(asyncReadyCallback) {
    elasticSearchConnect(function(error, client) {
      this.elasticSearch = client;
      asyncReadyCallback(error);
    }.bind(this));
  },

  connectBeanstalk: function(asyncReadyCallback) {
    var connected = false;
    this.beanstalk = new fivebeans.client(config.get('beanstalkd.host'), config.get('beanstalkd.port'));

    this.beanstalk.on('error', function(error) {
      logger.error('beanstalk error: ', error);
      if(!connected) {
        asyncReadyCallback(error);
      }
    });

    this.beanstalk.on('connect', function() {
      connected = true;
      this.beanstalk.watch('logs', function(error) {
        asyncReadyCallback(error);
      });
    }.bind(this));

    this.beanstalk.connect();
  },

  handleConnections: function(error) {
    if(error) {
      logger.error('Log processor worker connections error: ', error);
      process.exit(1);
      return false;
    }

    this.reserveJob();
    this.emit('ready');
  },

  reserveJob: function() {
    this.beanstalk.reserve(function(error, jobId, payload) {
      var logId = payload.toString();
      if(error) {
        logger.error('beanstalk reserve error: ', error);
        this.reserveJob();
        return false;
      }

      this.processLog(jobId, logId, function(error) {
        if(!error) {
          this.reserveJob();
        } else if(error === 'job_retry_reschedule_complete') {
          this.reserveJob();
        } else {
          this.rescheduleFailedJob(jobId, logId, function() {
            this.reserveJob();
          }.bind(this));
        }
      }.bind(this));

    }.bind(this));
  },

  processLog: function(jobId, logId, callback) {
    async.waterfall([
      this.fetchLogData.bind(this, logId),
      this.parseLogData.bind(this, logId),
      this.rescheduleIncompleteLog.bind(this, jobId, logId),
      this.cleanLogData.bind(this, logId),
      this.indexLog.bind(this, logId),
      this.deleteLogData.bind(this, logId),
      this.deleteJob.bind(this, jobId),
    ], callback);
  },

  fetchLogData: function(id, callback) {
    this.redis.hgetall('log:' + id, callback);
  },

  parseLogData: function(id, log, callback) {
    if(log) {
      if(log.initial_router) {
        log.initial_router = JSON.parse(log.initial_router);
      }

      if(log.gatekeeper) {
        log.gatekeeper = JSON.parse(log.gatekeeper);
      }

      if(log.api_backend_router) {
        log.api_backend_router = JSON.parse(log.api_backend_router);
      }
    }

    callback(null, log);
  },

  rescheduleIncompleteLog: function(jobId, logId, log, callback) {
    // If all the expected data is present, continue on in the processLog
    // chain.
    if(log && log.initial_router && log.gatekeeper && log.api_backend_router) {
      callback(null, log);

    // If the gatekeeper denied the request, then only the gatekeeper and
    // initial_router log data will be present, so continue on with
    // api_backend_router data missing.
    } else if(log && log.initial_router && log.gatekeeper && log.gatekeeper.gatekeeper_denied_code) {
      callback(null, log);

    // If gatekeeper and api_backend_router data are missing, and the response
    // was a 429, then that's a good indication that the user hit the
    // nginx-based rate limits, and the request never made it to the
    // gatekeeper. In this case we will continue on with only the
    // initial_router data, since don't want to keep retrying and piling up
    // logs in the queue if things are being overloaded.
    } else if(log && log.initial_router && !log.gatekeeper && !log.api_backend_router && log.initial_router.res_status === 429) {
      callback(null, log);

    // If gatekeeper and api_backend_router data are missing, and the response
    // was a 502, then that's a good indication that the gatekeeper is down. In
    // this case we will continue on with only the initial_router data. This is
    // an edge-case we hope to never encounter, but if we do, we don't want to
    // compound a server problem by piling up logs in the queue.
    } else if(log && log.initial_router && !log.gatekeeper && !log.api_backend_router && log.initial_router.res_status === 502) {
      callback(null, log);

    // If the response was a 499, then the client canceled the request before
    // the server responded. In this case, continue on with just initial_router
    // data present, since the other log data doesn't matter too much.
    } else if(log && log.initial_router && (!log.gatekeeper || !log.api_backend_router) && log.initial_router.res_status === 499) {
      callback(null, log);

    // Otherwise, we might temporarily be missing some log data due to out of
    // order log processing (since the nginx logs come in via UDP, order is not
    // guaranteed). In this case, retry a couple more times after waiting for
    // 5, then 10 seconds.
    } else {
      this.beanstalk.stats_job(jobId, function(error, stats) {
        var failedAttempts = 0;
        if(error || !stats || (typeof stats.releases) !== 'number') {
          logger.error('Failed to fetch beanstalk stats', { logId: logId, jobId: jobId, error: error });
        } else {
          failedAttempts = stats.releases;
        }

        if(failedAttempts >= 2) {
          callback('Incomplete log data');
        } else {
          // Retry twice after 5 and 10 seconds.
          var delay = 5 * (failedAttempts + 1);
          logger.warning('Log data incomplete - scheduling retry', { logId: logId, jobId: jobId, failedAttempts: failedAttempts, delay: delay, error: error });
          this.beanstalk.release(jobId, 50, delay, function(error) {
            if(error) {
              logger.error('beanstalk release error: ', error);
            }

            callback('job_retry_reschedule_complete');
          });
        }
      }.bind(this));
    }
  },

  cleanLogData: function(id, log, callback) {
    var combined = {};

    if(log.gatekeeper) {
      _.extend(combined, {
        api_key: log.gatekeeper.api_key,
        gatekeeper_denied_code: log.gatekeeper.gatekeeper_denied_code,
        internal_gatekeeper_time: log.gatekeeper.internal_gatekeeper_time,
        internal_response_time: log.gatekeeper.internal_response_time,
        user_email: log.gatekeeper.user_email,
        user_id: log.gatekeeper.user_id,
        user_registration_source: log.gatekeeper.user_registration_source,
      });
    }

    if(log.api_backend_router) {
      _.extend(combined, {
        backend_response_time: log.api_backend_router.res_time_backend * 1000,
      });
    }

    if(log.initial_router) {
      _.extend(combined, {
        request_accept: log.initial_router.req_accept,
        request_accept_encoding: log.initial_router.req_accept_encoding,
        request_at: moment.unix(log.initial_router.req_at_msec - log.initial_router.res_time).toISOString(),
        request_basic_auth_username: log.initial_router.req_basic_auth_username,
        request_connection: log.initial_router.req_connection,
        request_content_type: log.initial_router.req_content_type,
        request_host: log.initial_router.req_host,
        request_ip: log.initial_router.req_ip,
        request_method: log.initial_router.req_method,
        request_origin: log.initial_router.req_origin,
        request_referer: log.initial_router.req_referer,
        request_scheme: log.initial_router.req_scheme,
        request_size: log.initial_router.req_size,
        request_url: log.initial_router.req_scheme + '://' + log.initial_router.req_host + log.initial_router.req_uri,
        request_user_agent: log.initial_router.req_user_agent,
        response_age: log.initial_router.res_age,
        response_content_encoding: log.initial_router.res_content_encoding,
        response_content_length: log.initial_router.res_content_length,
        response_content_type: log.initial_router.res_content_type,
        response_server: log.initial_router.res_server,
        response_size: log.initial_router.res_size,
        response_status: log.initial_router.res_status,
        response_time: log.initial_router.res_time * 1000,
        response_transfer_encoding: log.initial_router.res_transfer_encoding,
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
            apiKey = log.initial_router.req_api_key_header;
            break;
          case 'getParam':
            apiKey = log.initial_router.req_api_key_query;
            break;
          case 'basicAuthUsername':
            apiKey = log.initial_router.req_basic_auth_username;
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
        combined.proxy_overhead = log.initial_router.res_time_backend * 1000 - combined.backend_response_time;
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
      callback(errorMessage);
    } else {
      logCleaner.all(this.elasticSearch, combined, callback);
    }
  },

  indexLog: function(id, log, callback) {
    var index = 'api-umbrella-logs-write-' + moment(log.request_at).utc().format('YYYY-MM');
    this.elasticSearch.index({
      index: index,
      type: 'log',
      id: id,
      body: log,
    }, function(error) {
      callback(error);
    });
  },

  deleteLogData: function(id, callback) {
    this.redis.del('log:' + id, function(error) {
      callback(error);
    });
  },

  deleteJob: function(jobId, callback) {
    this.beanstalk.destroy(jobId, function(error) {
      if(error) {
        logger.error('beanstalk destroy error: ', error);
      }

      callback();
    });
  },

  rescheduleFailedJob: function(jobId, logId, callback) {
    this.beanstalk.stats_job(jobId, function(error, stats) {
      var failedAttempts = 0;
      if(error || !stats || (typeof stats.releases) !== 'number') {
        logger.error('Failed to fetch beanstalk stats', { logId: logId, jobId: jobId, error: error });
      } else {
        failedAttempts = stats.releases;
      }

      if(failedAttempts > 10) {
        logger.error('Log processing failed too many times - burying permanently', { logId: logId, jobId: jobId, failedAttempts: failedAttempts, error: error });
        this.beanstalk.bury(jobId, 200, function(error) {
          if(error) {
            logger.error('beanstalk release error: ', error);
          }

          callback();
        });
      } else {
        // Exponential backoff for retry attempts.
        var delayBackoff = 30; // 30 seconds
        var delay = Math.pow(2, failedAttempts) * delayBackoff;

        logger.warning('Log processing failed - scheduling retry', { logId: logId, jobId: jobId, failedAttempts: failedAttempts, delay: delay, error: error });
        this.beanstalk.release(jobId, 100, delay, function(error) {
          if(error) {
            logger.error('beanstalk release error: ', error);
          }

          callback();
        });
      }
    }.bind(this));
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
