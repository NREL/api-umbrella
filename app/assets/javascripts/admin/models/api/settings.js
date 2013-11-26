Admin.ApiSettings = Ember.Model.extend({
  _id: Ember.attr(),
  appendQueryString: Ember.attr(),
  headersString: Ember.attr(),
  httpBasicAuth: Ember.attr(),
  requireHttps: Ember.attr(),
  disableApiKey: Ember.attr(),
  requiredRolesString: Ember.attr(),
  rateLimitMode: Ember.attr(),
  errorTemplates: Ember.attr(),
  errorDataYamlStrings: Ember.attr(),

  rateLimits: Ember.hasMany('Admin.ApiRateLimit', { key: 'rate_limits', embedded: true }),

  init: function() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults: function() {
    if(this.get('rateLimitMode') === undefined) {
      this.set('rateLimitMode', null);
    }

    // Make sure at least an empty object exists so the form builder can dive
    // into this section even when there's no pre-existing data.
    if(!this.get('errorTemplates')) {
      this.set('errorTemplates', {});
    }

    if(!this.get('errorDataYamlStrings')) {
      this.set('errorDataYamlStrings', {});
    }
  },

  isRateLimitModeCustom: function() {
    return (this.get('rateLimitMode') === 'custom');
  }.property('rateLimitMode'),
});

Admin.ApiSettings.primaryKey = "_id";
Admin.ApiSettings.camelizeKeys = true;
