Admin.ApisSettingsFieldsController = Ember.ObjectController.extend({
  requireHttpsOptions: [
    { id: null, name: "Inherit (default - optional)" },
    { id: false, name: "Optional - HTTPS is optional" },
    { id: true, name: "Required - HTTPS is mandatory" },
  ],

  disableApiKeyOptions: [
    { id: null, name: "Inherit (default - required)" },
    { id: false, name: "Required - API keys are mandatory" },
    { id: true, name: "Disabled - API keys are optional" },
  ],

  // FIXME: Don't use a global variable for getting the list of roles.
  roleOptions: apiUserExistingRoles,

  rateLimitModeOptions: [
    { id: null, name: "Default rate limits" },
    { id: "custom", name: "Custom rate limits" },
    { id: "unlimited", name: "Unlimited requests" },
  ],

  rateLimitDurationUnitOptions: [
    { id: "seconds", name: "seconds" },
    { id: "minutes", name: "minutes" },
    { id: "hours", name: "hours" },
    { id: "days", name: "days" },
  ],

  rateLimitLimitByOptions: [
    { id: "apiKey", name: "API Key" },
    { id: "ip", name: "IP Address" },
  ],

  uniqueSettingsId: function() {
    return _.uniqueId('api_settings_');
  }.property(),

  actions: {
    addRateLimit: function() {
      this.get('model.rateLimits').create();
    },

    deleteRateLimit: function(rateLimit) {
      var collection = this.get('model.rateLimits');
      bootbox.confirm('Are you sure you want to remove this rate limit?', function(result) {
        if(result) {
          collection.removeObject(rateLimit);
        }
      });
    },
  },
});
