'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    events = require('events'),
    ipaddr = require('ipaddr.js'),
    logger = require('../logger'),
    ndns = require('native-dns'),
    util = require('util');

var DnsResolver = function() {
  this.initialize.apply(this, arguments);
};

_.extend(DnsResolver, {
  NULL_ROUTE: '127.255.255.255',
});

util.inherits(DnsResolver, events.EventEmitter);
_.extend(DnsResolver.prototype, {
  resolved: {},
  resolveHostTimeouts: {},
  notFoundFailures: {},

  initialize: function(configReloader, callback) {
    this.configReloader = configReloader;
    this.resolveAllHosts(callback);
  },

  resolveAllHosts: function(callback) {
    var apis = config.get('internal_apis') || [];
    apis = apis.concat(config.get('apis') || []);

    var hosts = [];
    apis.forEach(function(api) {
      if(api.servers) {
        hosts = hosts.concat(_.pluck(api.servers, 'host'));
      }
    });

    var websiteBackends = config.get('internal_website_backends') || [];
    websiteBackends = websiteBackends.concat(config.get('website_backends') || []);
    hosts = hosts.concat(_.pluck(websiteBackends, 'server_host'));

    hosts = _.uniq(hosts);

    async.eachLimit(hosts, 5, this.resolveHost.bind(this), this.handleResolveAllHosts.bind(this, callback));
  },

  handleResolveAllHosts: function(callback, error) {
    callback(error, this);
  },

  resolveHost: function(host, resolveHostCallback) {
    if(this.resolveHostTimeouts[host]) {
      logger.info({ host: host }, 'Resolving host immediately - Clearing refresh of host that was scheduled for later');
    }

    // If an IP address was given as the host, we don't need to do anything
    // else.
    if(ipaddr.isValid(host)) {
      this.resolved[host] = {
        servers: [{
          address: host,
        }],
        isIp: true,
      };

      resolveHostCallback();
      return;
    }

    async.waterfall([
      this.sendHostQuery.bind(this, host),
      this.setResolvedHost.bind(this, host),
      this.scheduleHostRefresh.bind(this, host),
    ], resolveHostCallback);
  },

  resolveHostScheduled: function(host, resolveHostCallback) {
    this.resolveHostTimeouts[host] = null;
    this.resolveHost(host, resolveHostCallback);
  },

  sendHostQuery: function(host, asyncCallback) {
    var question = ndns.Question({
      name: host,
      type: 'A',
    });

    var request = ndns.Request({
      question: question,
      server: {
        address: '127.0.0.1',
        port: config.get('dnsmasq.port'),
      },
      timeout: 5000,
    });

    var resolved = {
      servers: [],
    };

    request.on('message', this.handleResolveHostMessage.bind(this, host, resolved));
    request.on('end', function() {
      asyncCallback(null, resolved);
    });

    // Log unexpected errors.
    request.on('timeout', function(error) {
      var existing = this.resolved[host];
      var logLevel = 'error';
      if(existing) {
        logLevel = 'info';
      }
      logger[logLevel]({ err: error, host: host, existing: existing }, 'Resolve host: timeout');
    }.bind(this));
    request.on('cancelled', function(error) {
      logger.error({ err: error, host: host }, 'Resolve host: cancelled');
    });

    request.send();
  },

  handleResolveHostMessage: function(host, resolved, error, message) {
    if(error) {
      logger.error({ err: error, host: host }, 'Resolve host: message error');
      return false;
    }

    if(message.header.rcode === ndns.consts.NAME_TO_RCODE.NOTFOUND || !message.answer || message.answer.length === 0) {
      // Keep track of how many times we've encountered a not found result for
      // this host.
      this.notFoundFailures[host] = this.notFoundFailures[host] || 0;
      this.notFoundFailures[host]++;

      // Adjust the log level on subsequent not found results (since the first
      // time we likely care, but subsequently we care less if the host is
      // permanently down).
      var logLevel = 'warn';
      if(this.notFoundFailures[host] > 1) {
        logLevel = 'info';
      }
      logger[logLevel]({ host: host, failures: this.notFoundFailures[host] }, 'Host not found');

      resolved.ttl = config.get('dns_resolver.minimum_ttl');
      resolved.servers = [{
        address: DnsResolver.NULL_ROUTE,
        down: true,
      }];

      return;
    }

    // Reset the not found counter if we have results.
    this.notFoundFailures[host] = 0;

    message.answer.forEach(function(answer) {
      if(answer.address) {
        resolved.servers.push({
          address: answer.address,
        });

        if(answer.ttl) {
          resolved.ttl = answer.ttl;
        }
      }
    });

    // Always sort the servers by address, so it's easier to compare the new
    // results to the old results (to see if they differ).
    resolved.servers = _.sortBy(resolved.servers, 'address');

    // Sporadically we've seen TTLs being reported back as 1 second for certain
    // domains for a while. This causes unnecessary cpu load and quick dns
    // polling, so force a minimum ttl.
    if(!resolved.ttl || resolved.ttl < config.get('dns_resolver.minimum_ttl')) {
      resolved.ttl = config.get('dns_resolver.minimum_ttl');
    }

    // Extremely large TTLs probably won't occur, but if they do, they break
    // setTimeout, so set a cap: http://stackoverflow.com/a/3468650/222487
    if(resolved.ttl > 2000000) {
      resolved.ttl = 2000000;
    }
  },

  setResolvedHost: function(host, resolved, asyncCallback) {
    // Only set the resolved host if we have new data (even if that data is a
    // null route returned by a NXDOMAIN not found result). Otherwise, we've
    // encountered some unexpected error and we should keep any existing cached
    // results.
    if(resolved.servers.length === 0) {
      var existing = this.resolved[host];
      var logLevel = 'error';
      if(this.notFoundFailures[host] && this.notFoundFailures[host] > 1) {
        logLevel = 'info';
      } else if(existing) {
        logLevel = 'info';
      }
      logger[logLevel]({ host: host, existing: existing }, 'Resolve host: Lookup unexpectedly failed, keeping existing');
    } else {
      var previousServers = [];
      if(this.resolved && this.resolved[host] && this.resolved[host].servers) {
        previousServers = this.resolved[host].servers;
      }

      var currentServers = [];
      if(resolved && resolved.servers) {
        currentServers = resolved.servers;
      }

      if(!_.isEqual(previousServers, currentServers)) {
        logger.info({ host: host, previous: this.resolved[host], current: resolved }, 'IP change for host');
        this.resolved[host] = resolved;
        this.emit('hostChanged', host, resolved.servers);
      }
    }

    asyncCallback();
  },

  scheduleHostRefresh: function(host, asyncCallback) {
    var resolved = this.resolved[host];
    if(!resolved || !resolved.isIp) {
      var ttl;
      if(resolved && resolved.ttl) {
        ttl = resolved.ttl;
      } else {
        ttl = config.get('dns_resolver.minimum_ttl');
      }

      if(this.resolveHostTimeouts[host]) {
        logger.info({ host: host, refreshIn: ttl }, 'Refresh of host is already scheduled');
      } else {
        logger.info({ host: host, refreshIn: ttl }, 'Scheduling refresh of host');
        this.resolveHostTimeouts[host] = setTimeout(this.resolveHostScheduled.bind(this, host), ttl * 1000);
      }
    }

    if(asyncCallback) {
      asyncCallback();
    }
  },

  getServers: function(host) {
    var servers = [];
    if(this.resolved[host]) {
      servers = this.resolved[host].servers;
    }

    if(!servers || servers.length === 0) {
      servers = [{
        address: DnsResolver.NULL_ROUTE,
        down: true,
      }];

      var logLevel = 'error';
      if(this.notFoundFailures[host] && this.notFoundFailures[host] > 1) {
        logLevel = 'info';
      }
      logger[logLevel]({ host: host, servers: servers }, 'Unexpectedly fetching servers for unknown host - using null route');
    }

    return servers;
  },

  getNginxServersConfig: function(host, port) {
    var resolvedServers = this.getServers(host);
    var nginxServers = _.map(resolvedServers, function(resolved) {
      var nginxServer = '';
      if(ipaddr.IPv6.isValid(resolved.address)) {
        nginxServer += '[' + resolved.address + ']';
      } else {
        nginxServer += resolved.address;
      }

      nginxServer += ':' + port;

      if(resolved.down) {
        nginxServer += ' down';
      }

      return nginxServer;
    });

    return nginxServers;
  },

  close: function(callback) {
    if(this.resolveHostTimeouts) {
      for(var host in this.resolveHostTimeouts) {
        clearTimeout(this.resolveHostTimeouts[host]);
      }
    }

    if(callback) {
      callback(null);
    }
  },
});

module.exports.DnsResolver = DnsResolver;
