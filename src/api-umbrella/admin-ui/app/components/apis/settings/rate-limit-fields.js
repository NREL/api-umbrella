import Ember from 'ember';

export default Ember.Component.extend({
  store: Ember.inject.service(),

  rateLimitModeOptions: [
    { id: null, name: 'Default rate limits' },
    { id: 'custom', name: 'Custom rate limits' },
    { id: 'custom-header', name: 'Custom rate limits based on response header' },
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
    { id: 'origin', name: 'Origin Header' },
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
