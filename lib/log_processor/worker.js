var _ = require('underscore'),
    async = require('async');
    Convoy = require('redis-convoy'),
    ElasticSearchClient = require('elasticsearchclient'),
    events = require('events'),
    fs = require('fs');
    geoip = undefined,
    moment = require('moment'),
    path = require('path');
    redis = require('redis'),
    url = require('url'),
    useragent = require('useragent'),
    util = require('util');

var Worker = function() {
  this.initialize.apply(this, arguments);
}

module.exports.Worker = Worker;

util.inherits(Worker, events.EventEmitter);
_.extend(Worker.prototype, {
  initialize: function(gatekeeper) {
    this.config = gatekeeper.config;

    // Don't require geoip until after the config is read in, so we have an
    // opportunity to set a custom global.geodatadir.
    geoip = require('geoip-lite'),

    async.parallel([
      this.connectRedis.bind(this),
      this.connectElasticsearch.bind(this),
    ], this.handleConnections.bind(this));
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

  connectElasticsearch: function(asyncReadyCallback) {
    this.elasticSearch = new ElasticSearchClient(this.config.get('elasticsearch'));

    var templatePath = path.join(process.cwd(), 'config', 'elasticsearch_template.json')
    fs.readFile(templatePath, this.handleElasticsearchReadTemplate.bind(this, asyncReadyCallback));
  },

  handleElasticsearchReadTemplate: function(asyncReadyCallback, error, template) {
    this.elasticSearch.defineTemplate('api-umbrella-log-template', JSON.parse(template.toString()), function() {
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

    this.queue = Convoy.createQueue('log_queue');
    this.queue.process(this.processQueue.bind(this));

    this.fetchJobs();

    this.emit('ready');
  },

  fetchJobs: function() {
    this.proxyLogger.fetchJobs(this.handleJobs.bind(this));
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
        if(error && error != 'committed') {
          asyncCallback(error);
          return false;
        }

        this.proxyLogger.deleteJob(id, asyncCallback);
      }.bind(this));
    }.bind(this), function() {
      // Look for new log jobs again after all the current stack of jobs have
      // been pushed onto the convoy queue.
      setTimeout(this.fetchJobs.bind(this), 5000);
    }.bind(this));
  },

  processQueue: function(job, done) {
    this.proxyLogger.fetchLog(job.id, this.handleLogFetch.bind(this, job.id, done));
  },

  handleLogFetch: function(id, done, error, log) {
    if(error) {
      done(error);
      return false;
    }

    var combined = {};

    if(log.proxy) {
      _.extend(combined, JSON.parse(log.proxy));
    }

    if(log.api_router) {
      var parts = log.api_router.split(' ');
      var times = parts[4].split('/');
      combined.backend_response_time = parseInt(times[2]) + parseInt(times[3]);
    }

    if(log.web_router) {
      var parts = log.web_router.split(' ');
      var date = parts[1].split(/[:.\/\[\]]/)
      var times = parts[4].split('/');

      combined.request_at = moment.utc(parts[1], "[DD/MMM/YYYY:HH:mm:ss.SSS]").toISOString();
      combined.response_status = parseInt(parts[5]);
      combined.response_size = parseInt(parts[6]);
      combined.request_size = parseInt(parts[7]);
      combined.response_time = parseInt(times[4]);

      if(combined.hasOwnProperty('backend_response_time')) {
        combined.proxy_overhead = combined.response_time - combined.backend_response_time;
      }
    }

    if(combined.request_ip) {
      var geo = geoip.lookup(combined.request_ip);
      if(geo) {
        combined.request_ip_country = geo.country;
        combined.request_ip_region = geo.region;
        combined.request_ip_city = geo.city;
        combined.request_ip_location = geo.ll;
      }
    }

    var urlParts = url.parse(combined.request_url, true);
    combined.request_path = urlParts.pathname.replace(/\.\w+$/, '');

    if(combined.request_url.indexOf("api_key") != -1) {
      delete urlParts.search;
      delete urlParts.query.api_key;
      combined.request_url = url.format(urlParts);
    }

    if(combined.request_user_agent) {
      var agent = useragent.parse(combined.request_user_agent);
      combined.request_user_agent_family = agent.family;
    }

    console.info(combined);

    var index = 'api-umbrella-logs-' + combined.request_at.substring(0, 10);
    this.elasticSearch.index(index, 'log', combined, id)
      .on('done', this.handleLogIndexed.bind(this, id, done))
      .on('done', this.handleLogIndexError.bind(this, done))
      .exec();
  },

  handleLogIndexed: function(id, done) {
    this.proxyLogger.deleteLog(id);
    done(null);
  },

  handleLogIndexError: function(done, error) {
    done(error);
  },
});
