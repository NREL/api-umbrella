'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('../config'),
    dns = require('native-dns'),
    events = require('events'),
    ipaddr = require('ipaddr.js'),
    logger = require('../logger'),
    moment = require('moment'),
    redis = require('redis'),
    util = require('util');

var DnsResolver = function() {
  this.initialize.apply(this, arguments);
};

_.extend(DnsResolver, {
  NULL_ROUTE: '255.255.255.255',
  RECENT_IP_BUCKET_TIME_FORMAT: 'YYYY-MM-DDTHH',
});

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

    async.eachSeries(hosts, this.resolveHost.bind(this), this.handleResolveAllHosts.bind(this, callback));
  },

  handleResolveAllHosts: function(callback) {
    callback(null);
  },

  resolveHost: function(host, resolveHostCallback) {
    logger.debug('Resolving host: ', host);

    if(!this.resolved[host]) {
      this.resolved[host] = {
        ips: [],
        names: [],
      };
    }

    // If an IP address was given as the host, we don't need to do anything
    // else.
    if(ipaddr.isValid(host)) {
      _.merge(this.resolved[host], {
        ips: [host],
        existingIp: host,
        activeIp: host,
        ttl: null,
      });

      this.finishResolveHost(host, resolveHostCallback);
      return false;
    }

    async.series([
      this.fetchCachedHost.bind(this, host),
      this.sendHostQuery.bind(this, host),
      this.lookupFallback.bind(this, host),
      this.setActiveIp.bind(this, host),
    ], this.finishResolveHost.bind(this, host, resolveHostCallback));
  },

  fetchCachedHost: function(host, asyncCallback) {
    var resolved = this.resolved[host];
    if(resolved.activeIp) {
      resolved.existingIp = resolved.activeIp;
      resolved.activeIp = null;

      asyncCallback(null);
    } else {
      this.redis.get('router_active_ip:' + host, function(error, ip) {
        if(error) {
          logger.error('Error fetching active IP: ', error);
          asyncCallback(error);
        }

        if(ip) {
          resolved.existingIp = ip;
        }

        asyncCallback(null);
      }.bind(this));
    }
  },

  sendHostQuery: function(host, asyncCallback) {
    var question = dns.Question({
      name: host,
      type: 'A',
    });

    var request = dns.Request({
      question: question,
      server: this.nameServers[0],
      timeout: 5000,
    });

    request.on('message', this.handleResolveHostMessage.bind(this, host));
    request.on('end', asyncCallback);

    request.send();
  },

  handleResolveHostMessage: function(host, error, message) {
    if(error) {
      return false;
    }

    var resolved = this.resolved[host];

    message.answer.forEach(function(answer) {
      if(answer.address) {
        logger.debug('Resolved host: ', host, answer.name, answer.address);
        resolved.ips.push(answer.address);

        if(answer.name) {
          resolved.names.push(answer.name);
        }

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
  },

  lookupFallback: function(host, asyncCallback) {
    var resolved = this.resolved[host];

    // If the domain couldn't be resolved by the DNS A record query, try a
    // local lookup. This helps resolve local hostnames, like 'localhost' or
    // other aliases that might be used.
    if(!resolved || !resolved.ips || resolved.ips.length === 0) {
      dns.lookup(host, function(error, ip) {
        if(!error && ip) {
          _.merge(resolved, {
            ips: [ip],
            ttl: 60 * 60, // 1 hour
          });
        }

        asyncCallback(null);
      }.bind(this));
    } else {
      asyncCallback(null);
    }
  },

  setActiveIp: function(host, asyncCallback) {
    var resolved = this.resolved[host];

    this.addRecentlySeenIps(host, resolved, function() {
      this.getRecentlySeenIps(host, function(error, recentIps) {
        recentIps += resolved.ips;

        if(!resolved.activeIp) {
          if(recentIps && recentIps.length > 0) {
            // If we know what IP is already being used by the system, try to use that
            // one if it's still in the list of recently seen valid IPs.
            // Otherwise, pick the first one from the list.
            //
            // Because we're checking over the recently seen IPs in the past 4
            // hours, this doesn't exactly respect the true TTL of the domains.
            // But without this, we end up swapping IPs and reloading nginx too
            // frequently for domains behind CDNs like Akamai.
            if(resolved.existingIp && recentIps.indexOf(resolved.existingIp) !== -1) {
              resolved.activeIp = resolved.existingIp;
            } else {
              resolved.activeIp = resolved.ips[0];
            }
          } else {
            var ip;
            if(resolved.existingIp && resolved.existingIp !== DnsResolver.NULL_ROUTE) {
              logger.error('Unable to resolve host: ' +  host + ' (using cached IP: ' + resolved.existingIp + ')');
              resolved.activeIp = resolved.existingIp;
            } else {
              logger.error('Unable to resolve host: ' +  host + ' (using null route...)');
              resolved.activeIp = DnsResolver.NULL_ROUTE;
            }

            _.merge(resolved, {
              activeIp: ip,
              ttl: 2 * 60, // 2 minutes
            });
          }
        }

        asyncCallback(null);
      }.bind(this));
    }.bind(this));
  },

  finishResolveHost: function(host, resolveHostCallback) {
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
      this.redis.set('router_active_ip:' + host, resolved.activeIp, function(error) {
        if(error) {
          logger.error('Error caching active IP: ', error);
        }
      });
    }
  },

  addRecentlySeenIps: function(host, resolved, callback) {
    var ips = resolved.ips;
    if(!ips || ips.length === 0) {
      callback(null);
      return false;
    }

    ips = _.uniq(ips);

    var names = resolved.names;
    names.push(host);
    names = _.uniq(names);

    var ignoreTtlDomains = config.get('dns_resolver.ignore_ttl_domains');
    var ignoreTtl = false;
    if(ignoreTtlDomains) {
      ignoreTtlDomains.forEach(function(ignore) {
        names.forEach(function(name) {
          if(name.match(ignore)) {
            ignoreTtl = true;
          }
        });
      });
    }

    if(!ignoreTtl) {
      callback(null);
      return false;
    }

    var setKey = 'router_seen_ips:' + host + ':' + moment().format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);

    logger.debug('Set: ', host, ignoreTtl, ips);
    this.redis.multi()
      .sadd(setKey, ips)
      .expire(setKey, 5 * 60 * 60) // 5 hours
      .exec(function(error) {
        if(error) {
          logger.error('Error setting recently seen ips:', error);
        }

        callback(null);
      });
  },

  getRecentlySeenIps: function(host, callback) {
    var now = moment();
    async.times(4, function(i, setCallback) {
      var hour = now.subtract('hours', i);
      var setKey = 'router_seen_ips:' + host + ':' + hour.format(DnsResolver.RECENT_IP_BUCKET_TIME_FORMAT);
      this.redis.smembers(setKey, function(error, ips) {
        if(error) {
          logger.error('Error fetching recently seen ips:', error);
          setCallback(null, []);
          return false;
        }

        setCallback(null, ips || []);
      }.bind(this));
    }.bind(this), function(error, ips) {
      var allIps = _.uniq(_.flatten(ips));
      if(allIps && allIps.length > 0) {
        logger.debug('Recently cached IPs: ', host, ips);
      }

      callback(error, allIps);
    });
  },

  getIp: function(host) {
    var ip;
    if(this.resolved[host]) {
      ip = this.resolved[host].activeIp;
    }

    if(!ip) {
      logger.error('Unexpectedly fetching IP for unknown host: ', host);
      ip = DnsResolver.NULL_ROUTE;
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
