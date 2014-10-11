'use strict';

var _ = require('lodash'),
    async = require('async'),
    config = require('api-umbrella-config').global(),
    dns = require('native-dns'),
    events = require('events'),
    ipaddr = require('ipaddr.js'),
    logger = require('../logger'),
    moment = require('moment'),
    nodeDns = require('dns'),
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
  resolveHostTimeouts: {},

  initialize: function(configReloader, callback) {
    this.configReloader = configReloader;

    async.parallel([
      this.connectRedis.bind(this),
      this.fetchSystemNameServers.bind(this),
    ], this.finishInit.bind(this, callback));
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
    var apis = config.get('internal_apis') || [];
    apis = apis.concat(config.get('apis') || []);

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
    logger.info('Resolving host: ', host);

    if(!this.resolved[host]) {
      this.resolved[host] = {
        ips: [],
        names: [],
      };
    }

    // If an IP address was given as the host, we don't need to do anything
    // else.
    if(ipaddr.isValid(host)) {
      _.extend(this.resolved[host], {
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

    _.extend(this.resolved[host], {
      ips: [],
      names: [],
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
        logger.info('Resolved host: ', host, answer.name, answer.address);
        resolved.ips.push(answer.address);
        resolved.ips = _.uniq(resolved.ips);

        if(answer.name) {
          resolved.names.push(answer.name);
          resolved.names = _.uniq(resolved.names);
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

    // Sporadically we've seen TTLs being reported back as 1 second for certain
    // domains for a while. This causes unnecessary cpu load and quick dns
    // polling, so force a minimum ttl of 40 seconds.
    if(resolved.ttl < config.get('dns_resolver.minimum_ttl')) {
      resolved.ttl = config.get('dns_resolver.minimum_ttl');
    }
  },

  lookupFallback: function(host, asyncCallback) {
    var resolved = this.resolved[host];

    // If the domain couldn't be resolved by the DNS A record query, try a
    // local lookup. This helps resolve local hostnames, like 'localhost' or
    // other aliases that might be used.
    if(!resolved || !resolved.ips || resolved.ips.length === 0) {
      // FIXME: Investigate why "native-dns" sometimes throws ETIMEDOUT errors
      // for dns.lookup calls for invalid domains after 60 seconds (rather than
      // calling the callback with an error). The problem seems isolated to
      // certain VM environments (it's happening on my VirtualBox VM right
      // now), but seems a bit sporadic. Probably need to file an issue with
      // the native-dns project.
      //
      // So instead, for now we're using node.js's built-in dns library for
      // this lookup call. Everywhere else we're using the "native-dns" module,
      // which is supposed to be a drop-in replacement (but seems funky for
      // this lookup call).
      nodeDns.lookup(host, function(error, ip) {
        if(!error && ip) {
          _.extend(resolved, {
            ips: [ip],
            ttl: 60 * 60, // 1 hour
          });
        } else {
          logger.error('Unable to resolve host via lookup or fallback: ' +  host);
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

        if(!resolved.activeIp && recentIps && recentIps.length > 0) {
          // If we know what IP is already being used by the system, try to use that
          // one if it's still in the list of recently seen valid IPs.
          // Otherwise, pick the first one from the list.
          //
          // Because we're checking over the recently seen IPs in the past 2
          // hours, this doesn't exactly respect the true TTL of the domains.
          // But without this, we end up swapping IPs and reloading nginx too
          // frequently for domains behind CDNs like Akamai.
          if(resolved.existingIp && recentIps.indexOf(resolved.existingIp) !== -1) {
            resolved.activeIp = resolved.existingIp;
          } else if(resolved.ips && resolved.ips[0]) {
            resolved.activeIp = resolved.ips[0];
          }
        }

        if(!resolved.activeIp) {
          var ip;
          if(resolved.existingIp && resolved.existingIp !== DnsResolver.NULL_ROUTE) {
            ip = resolved.existingIp;
            logger.error('Unable to resolve host: ' +  host + ' (using cached IP: ' + ip + ')');
          } else if(recentIps && recentIps[0] && recentIps[0] !== DnsResolver.NULL_ROUTE) {
            ip = recentIps[0];
            logger.error('Unable to resolve host: ' +  host + ' (using recent IP: ' + ip + ')');
          } else {
            ip = DnsResolver.NULL_ROUTE;
            logger.error('Unable to resolve host: ' +  host + ' (using null route...)');
          }

          _.extend(resolved, {
            activeIp: ip,
            ttl: 2 * 60, // 2 minutes
          });
        }

        asyncCallback(null);
      }.bind(this));
    }.bind(this));
  },

  finishResolveHost: function(host, resolveHostCallback) {
    var resolved = this.resolved[host];

    if(resolved.activeIp !== resolved.existingIp) {
      logger.info('IP change for ' + host + ': ' + resolved.existingIp + ' => ' + resolved.activeIp);
      this.emit('hostChanged', host, resolved.activeIp);
    }

    if(resolveHostCallback) {
      resolveHostCallback(null);
    }

    if(resolved.ttl) {
      logger.info('Scheduling refresh of ' + host + ' (' + resolved.activeIp + ') in ' + resolved.ttl + ' seconds');
      this.resolveHostTimeouts[host] = setTimeout(this.resolveHost.bind(this, host), resolved.ttl * 1000);
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

    var names = [host];
    if(resolved.names) {
      names = names.concat(resolved.names);
    }

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

    logger.info('Set: ', host, ignoreTtl, ips);
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
    async.times(2, function(i, setCallback) {
      var hour = now.subtract(i, 'hours');
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
        logger.info('Recently cached IPs: ', host, ips);
      }

      callback(error, allIps);
    });
  },

  getIp: function(host) {
    var ip;
    if(this.resolved[host]) {
      ip = this.resolved[host].activeIp;

      if(!ip && this.resolved[host].existingIp) {
        ip = this.resolved[host].existingIp;
        logger.warning('Unexpectedly using existing IP for host: ' +  host + ' (using existing ip: ' + ip + ')');
      }
    }

    if(!ip) {
      ip = DnsResolver.NULL_ROUTE;
      logger.error('Unexpectedly fetching IP for unknown host: ' +  host + ' (using null route: ' + ip + ')');
    }

    return ip;
  },

  close: function(callback) {
    if(this.redis) {
      this.redis.quit();
    }

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
