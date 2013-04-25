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
    this.proxyLogger = gatekeeper.proxyLogger;

    this.queue = Convoy.createQueue('log_queue');
    this.queue.process(this.processQueue.bind(this));

    this.elasticSearch = new ElasticSearchClient({
      host: 'localhost',
      port: 9200,
    });

    this.fetchJobs();
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

