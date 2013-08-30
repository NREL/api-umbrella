Admin.Api = Ember.Model.extend({
  name: Ember.attr(),
  sortOrder: Ember.attr(),
  backendProtocol: Ember.attr(),
  frontendHost: Ember.attr(),
  backendHost: Ember.attr(),
  requireHttps: Ember.attr(),
  appendQueryString: Ember.attr(),
  headersString: Ember.attr(),
  httpBasicAuth: Ember.attr(),
  requiredRoles: Ember.attr(),
  balanceAlgorithm: Ember.attr(),

  servers: Ember.hasMany('Admin.ApiServer', { key: 'servers', embedded: true }),
  urlMatches: Ember.hasMany('Admin.ApiUrlMatch', { key: 'url_matches', embedded: true }),
  rewrites: Ember.hasMany('Admin.ApiRewrite', { key: 'rewrites', embedded: true }),
  //rateLimits: Ember.hasMany('Admin.ApiRateLimit', { key: 'rate_limits', embedded: true }),

  exampleIncomingUrlRoot: function() {
    return 'http://' + this.get('frontendHost');
  }.property('frontendHost'),

  exampleOutgoingUrlRoot: function() {
    var server = this.get('servers.firstObject');
    if(server) {
      return this.get('backendProtocol') + server.get('urlString');
    } else {
      return 'http://localhost';
    }
  }.property('servers.firstObject'),

  headers: function(key, value) {
    console.info("HEADER: %o", arguments);
  }.property('headersString'),
})

Admin.Api.url = "/admin/apis";
Admin.Api.rootKey = "api";
Admin.Api.collectionKey = "apis";
Admin.Api.primaryKey = "_id";
Admin.Api.camelizeKeys = true;
Admin.Api.adapter = Ember.RESTAdapter.create();
