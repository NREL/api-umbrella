Admin.ApiSettings = Ember.Model.extend({
  _id: Ember.attr(),
  appendQueryString: Ember.attr(),
  headersString: Ember.attr(),
  httpBasicAuth: Ember.attr(),
  requireHttps: Ember.attr(),
  disableApiKey: Ember.attr(),
  requiredRolesString: Ember.attr(),
  hourlyRateLimit: Ember.attr(),
  errorTemplates: Ember.attr(),
  errorDataYamlStrings: Ember.attr(),

  headers: function(key, value) {
    console.info("HEADER: %o", arguments);
  }.property('headersString'),
});

Admin.ApiSettings.primaryKey = "_id";
Admin.ApiSettings.camelizeKeys = true;
