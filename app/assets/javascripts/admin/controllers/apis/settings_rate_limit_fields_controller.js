Admin.ApisSettingsRateLimitFieldsController = Ember.ObjectController.extend({
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

  anonymousRateLimitBehaviorOptions: [
    { id: "ip_fallback", name: "IP Fallback - API key rate limits are applied as IP limits" },
    { id: "ip_only", name: "IP Only - API key rate limits are ignored (only IP based limits are applied)" },
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
