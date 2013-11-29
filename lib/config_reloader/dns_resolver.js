'use strict';

var _ = require('lodash'),
    async = require('async'),
    dns = require('native-dns'),
    events = require('events'),
    ipaddr = require('ipaddr.js'),
    logger = require('../logger'),
    util = require('util');

var DnsResolver = function() {
  this.initialize.apply(this, arguments);
};

util.inherits(DnsResolver, events.EventEmitter);
_.extend(DnsResolver.prototype, {
  resolved: {},

  initialize: function(configReloader) {
    this.configReloader = configReloader;
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

  resolveHost: function(host, callback) {
    logger.info('Resolving host: ', host);

    if(ipaddr.isValid(host)) {
      this.resolved[host] = {
        ips: [host],
        activeIp: host,
        ttl: null,
      };

      this.handleResolveHostEnd(host, callback);
      return false;
    }

    var question = dns.Question({
      name: host,
      type: 'A',
    });

    var request = dns.Request({
      question: question,
      server: { address: '8.8.8.8', port: 53, type: 'udp' },
      timeout: 1000,
    });

    request.on('message', this.handleResolveHostMessage.bind(this, host));
    request.on('end', this.handleResolveHostEnd.bind(this, host, callback));

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
    if(existing && resolved.ips.indexOf(existing.activeIp) !== -1) {
      resolved.activeIp = existing.activeIp;
    } else {
      resolved.activeIp = resolved.ips[0];
    }

    this.resolved[host] = resolved;
  },

  handleResolveHostEnd: function(host, callback) {
    var resolved = this.resolved[host];
    if(!resolved || !resolved.ips || resolved.ips.length === 0) {
      logger.error('Unable to resolve host: ' +  host + ' (using null route...)');

      resolved = {
        ips: ['0.0.0.0'],
        activeIp: '0.0.0.0',
        ttl: 2 * 60, // 2 minutes
      };

      this.resolved[host] = resolved;
    }

    this.emit('hostResolved');
    if(callback) {
      callback(null);
    }

    if(resolved.ttl) {
      logger.info('Scheduling refresh of ' + host + ' (' + resolved.activeIp + ') in ' + resolved.ttl + ' seconds');
      setTimeout(this.resolveHost.bind(this, host), resolved.ttl * 1000);
    }
  },

  getIp: function(host) {
    var ip;
    if(this.resolved[host]) {
      ip = this.resolved[host].activeIp;
    }

    if(!ip) {
      logger.error('Unexpectedly fetching IP for unknown host: ', host);
      ip = '0.0.0.0';
    }

    return ip;
  },
});

module.exports.DnsResolver = DnsResolver;
