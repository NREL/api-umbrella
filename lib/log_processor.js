var _ = require('underscore'),
    async = require('async');
    Convoy = require('redis-convoy'),
    ElasticSearchClient = require('elasticsearchclient'),
    geoip = require('geoip-lite');

module.exports.process = function(gatekeeper) {
  return new LogProcessor(gatekeeper);
}

var LogProcessor = function() {
  this.initialize.apply(this, arguments);
}

_.extend(LogProcessor.prototype, {
  initialize: function(gatekeeper) {
    this.gatekeeper = gatekeeper;
    this.redis = gatekeeper.redis;

    this.queue = Convoy.createQueue('log_queue');
    this.queue.process(this.processJob.bind(this));

    this.elasticSearch = new ElasticSearchClient({
      host: 'localhost',
      port: 9200,
    });

    this.fetchJobs();
  },

  fetchJobs: function() {
    this.redis.zrangebyscore('log_jobs', '-inf', Date.now(), this.handleJobs.bind(this));
  },

  handleJobs: function(error, ids) {
    async.each(ids, function(id, asyncCallback) {
      var job = new Convoy.Job(id);
      this.queue.addJob(job, function(error) {
        if(error && error != 'committed') {
          asyncCallback(error);
          return false;
        }

        this.redis.zrem('log_jobs', id, function(error) {
          asyncCallback(error);
        });
      }.bind(this));
    }.bind(this), function() {
      setTimeout(this.fetchJobs.bind(this), 5000);
    }.bind(this));
  },

  processJob: function(job, done) {
    this.redis.hgetall('log:' + job.id, this.handleLogFetch.bind(this, job.id, done));
  },

  handleLogFetch: function(id, done, error, log) {
    if(error) {
      done(error);
      return false;
    }

    console.info(arguments);

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
      var times = parts[4].split('/');
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

    console.info("LOGGING: ", combined);

    this.elasticSearch.index('logs', 'log', combined, id)
      .on('data', function(data) {
      })
      .exec();
  }
});

