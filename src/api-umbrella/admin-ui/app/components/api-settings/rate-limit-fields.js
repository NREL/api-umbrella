import Ember from 'ember';

export default Ember.Component.extend({
  store: Ember.inject.service(),

  rateLimitModeOptions: [
    { id: null, name: 'Default rate limits' },
    { id: 'custom', name: 'Custom rate limits' },
    { id: 'unlimited', name: 'Unlimited requests' },
  ],

  rateLimitDurationUnitOptions: [
    { id: 'seconds', name: 'seconds' },
    { id: 'minutes', name: 'minutes' },
    { id: 'hours', name: 'hours' },
    { id: 'days', name: 'days' },
  ],

  rateLimitLimitByOptions: [
    { id: 'apiKey', name: 'API Key' },
    { id: 'ip', name: 'IP Address' },
  ],

  anonymousRateLimitBehaviorOptions: [
    { id: 'ip_fallback', name: 'IP Fallback - API key rate limits are applied as IP limits' },
    { id: 'ip_only', name: 'IP Only - API key rate limits are ignored (only IP based limits are applied)' },
  ],

  authenticatedRateLimitBehaviorOptions: [
    { id: 'all', name: 'All Limits - Both API key rate limits and IP based limits are applied' },
    { id: 'api_key_only', name: 'API Key Only - IP based rate limits are ignored (only API key limits are applied)' },
  ],

  uniqueSettingsId: Ember.computed(function() {
    return _.uniqueId('api_settings_');
  }),

  actions: {
    primaryRateLimitChange(selectedRateLimit) {
      let rateLimits = this.get('model.rateLimits');
      rateLimits.forEach(function(rateLimit) {
        if(rateLimit === selectedRateLimit) {
          rateLimit.set('responseHeaders', true);
        } else {
          rateLimit.set('responseHeaders', false);
        }
      });
    },

    addRateLimit() {
      let collection = this.get('model.rateLimits');
      collection.pushObject(this.get('store').createRecord('api/rate-limit'));
    },

    deleteRateLimit(rateLimit) {
      let collection = this.get('model.rateLimits');
      bootbox.confirm('Are you sure you want to remove this rate limit?', function(result) {
        if(result) {
          collection.removeObject(rateLimit);
        }
      });
    },
  },
});
