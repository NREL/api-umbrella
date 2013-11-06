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

  init: function() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults: function() {
    // Make sure at least an empty object exists so the form builder can dive
    // into this section even when there's no pre-existing data.
    if(!this.get('errorTemplates')) {
      this.set('errorTemplates', {});
    }

    if(!this.get('errorDataYamlStrings')) {
      this.set('errorDataYamlStrings', {});
    }
  },
});

Admin.ApiSettings.primaryKey = "_id";
Admin.ApiSettings.camelizeKeys = true;
