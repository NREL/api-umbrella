'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('../config'),
    dns = require('native-dns'),
    events = require('events'),
    ipaddr = require('ipaddr.js'),
    logger = require('../logger'),
    redis = require('redis'),
    util = require('util');

var DnsResolver = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(DnsResolver, events.EventEmitter);
_.extend(DnsResolver.prototype, {
  resolved: {},

  initialize: function(configReloader, callback) {
    this.configReloader = configReloader;

    async.parallel([
      this.connectRedis.bind(this),
      this.fetchSystemNameServers.bind(this),
    ], this.finishInit.bind(this, callback));
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

  fetchSystemNameServers: function(asyncReadyCallback) {
    this.nameServers = dns.platform.name_servers;
    if(this.nameServers && this.nameServers.length > 0) {
      asyncReadyCallback(null);
    } else {
      dns.platform.once('ready', function() {
        this.nameServers = dns.platform.name_servers;
        asyncReadyCallback(null);
      }.bind(this));
    }
  },

  finishInit: function(callback, error) {
    logger.info('System DNS discovered: ', this.nameServers);

    // Watch for future changes to the system's DNS settings.
    dns.platform.watching = true;
    dns.platform.on('ready', this.handleNameServerChanges.bind(this));

    if(callback) {
      callback(error);
    }
  },

  handleNameServerChanges: function() {
    this.nameServers = dns.platform.name_servers;
    logger.info('System DNS changes detected. Using new name servers: ', this.nameServers);
  },

  resolveAllHosts: function(callback) {
    var apis = this.configReloader.apis;

    var hosts = [];
    apis.forEach(function(api) {
      if(api.servers) {
        hosts = hosts.concat(_.pluck(api.servers, 'host'));
      }
    });

    hosts = _.uniq(hosts);

    async.eachLimit(hosts, 5, this.resolveHost.bind(this), this.handleResolveAllHosts.bind(this, callback));
  },

  handleResolveAllHosts: function(callback) {
    callback(null);
  },

  resolveHost: function(host, resolveHostCallback) {
    logger.debug('Resolving host: ', host);

    // If an IP address was given as the host, we don't need to do anything
    // else.
    if(ipaddr.isValid(host)) {
      this.resolved[host] = {
        ips: [host],
        existingIp: host,
        activeIp: host,
        ttl: null,
      };

      this.handleResolveHost(host, resolveHostCallback);
      return false;
    }

    async.series([
      this.fetchCachedHost.bind(this, host),
      this.sendHostQuery.bind(this, host),
      this.lookupFallback.bind(this, host),
      this.cacheOrDefaultFallback.bind(this, host),
    ], this.handleResolveHost.bind(this, host, resolveHostCallback));
  },

  fetchCachedHost: function(host, asyncCallback) {
    this.redis.get('router_active_ip:' + host, function(error, ip) {
      if(error) {
        logger.error('Error fetching active IP: ', error);
        asyncCallback(error);
      }

      if(ip) {
        this.resolved[host] = {
          ips: [ip],
          activeIp: ip,
          ttl: null,
        };
      }

      asyncCallback(null);
    }.bind(this));
  },

  sendHostQuery: function(host, asyncCallback) {
    var question = dns.Question({
      name: host,
      type: 'A',
    });

    var request = dns.Request({
      question: question,
      server: this.nameServers[0],
      timeout: 1000,
    });

    request.on('message', this.handleResolveHostMessage.bind(this, host));
    request.on('end', asyncCallback);

    request.send();
  },

  handleResolveHostMessage: function(host, error, message) {
    if(error) {
      return false;
    }

    var resolved = {
      ips: [],
    };

    message.answer.forEach(function(answer) {
      if(answer.address) {
        resolved.ips.push(answer.address);

        if(answer.ttl && !resolved.ttl) {
          resolved.ttl = answer.ttl;
        }
      }
    });

    if(!resolved.ttl) {
      resolved.ttl = 60 * 60; // 1 hour
    }

    // Extremely large TTLs probably won't occur, but if they do, they break
    // setTimeout, so set a cap: http://stackoverflow.com/a/3468650/222487
    if(resolved.ttl > 2000000) {
      resolved.ttl = 2000000;
    }

    var existing = this.resolved[host];
    if(existing && existing.activeIp) {
      resolved.existingIp = existing.activeIp;
    }

    // If we know what IP is already being used by the system, try to use that
    // one if it's still in the list of valid IPs. Otherwise, pick the first
    // one from the list.
    if(resolved.existingIp && resolved.ips.indexOf(resolved.existingIp) !== -1) {
      resolved.activeIp = resolved.existingIp;
    } else {
      resolved.activeIp = resolved.ips[0];
    }

    this.resolved[host] = resolved;
  },

  lookupFallback: function(host, asyncCallback) {
    var resolved = this.resolved[host];

    // If the domain couldn't be resolved by the DNS A record query, try a
    // local lookup. This helps resolve local hostnames, like 'localhost' or
    // other aliases that might be used.
    if(!resolved || !resolved.activeIp || resolved.activeIp === '255.255.255.255') {
      dns.lookup(host, function(error, ip) {
        if(!error && ip) {
          _.merge(resolved, {
            ips: [ip],
            activeIp: ip,
            ttl: 2 * 60, // 2 minutes
          });
        }

        asyncCallback(null);
      }.bind(this));
    } else {
      asyncCallback(null);
    }
  },

  cacheOrDefaultFallback: function(host, asyncCallback) {
    var resolved = this.resolved[host];
    if(!resolved || !resolved.activeIp) {
      var ip;
      if(resolved && resolved.existingIp) {
        logger.error('Unable to resolve host: ' +  host + ' (using cached IP: ' + resolved.existingIp + ')');
        ip = resolved.existingIp;
      } else {
        logger.error('Unable to resolve host: ' +  host + ' (using null route...)');
        ip = '255.255.255.255';
      }

      _.merge(resolved, {
        ips: [ip],
        activeIp: ip,
        ttl: 2 * 60, // 2 minutes
      });
    }

    asyncCallback(null);
  },

  handleResolveHost: function(host, resolveHostCallback) {
    var resolved = this.resolved[host];

    if(resolved.activeIp !== resolved.existingIp) {
      logger.info('IP change for ' + host + ': ' + resolved.existingIp + ' => ' + resolved.activeIp);
      this.emit('hostChanged');
    }

    if(resolveHostCallback) {
      resolveHostCallback(null);
    }

    if(resolved.ttl) {
      logger.debug('Scheduling refresh of ' + host + ' (' + resolved.activeIp + ') in ' + resolved.ttl + ' seconds');
      setTimeout(this.resolveHost.bind(this, host), resolved.ttl * 1000);
    }

    if(resolved.activeIp !== resolved.existingIp) {
      var cacheIp = resolved.activeIp;
      if(cacheIp === '255.255.255.255') {
        cacheIp = null;
      }

      if(cacheIp) {
        this.redis.set('router_active_ip:' + host, cacheIp, function(error) {
          if(error) {
            logger.error('Error caching active IP: ', error);
          }
        });
      }
    }
  },

  getIp: function(host) {
    var ip;
    if(this.resolved[host]) {
      ip = this.resolved[host].activeIp;
    }

    if(!ip) {
      logger.error('Unexpectedly fetching IP for unknown host: ', host);
      ip = '255.255.255.255';
    }

    return ip;
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

module.exports.DnsResolver = DnsResolver;
