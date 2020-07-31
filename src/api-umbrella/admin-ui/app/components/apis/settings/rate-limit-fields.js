import Component from '@ember/component';
import bootbox from 'bootbox';
import { computed } from '@ember/object';
import { inject } from '@ember/service';
import uniqueId from 'lodash-es/uniqueId';

export default Component.extend({
  store: inject(),

  init() {
    this._super(...arguments);

    this.rateLimitModeOptions = [
      { id: null, name: 'Default rate limits' },
      { id: 'custom', name: 'Custom rate limits' },
      { id: 'unlimited', name: 'Unlimited requests' },
    ];

    this.rateLimitDurationUnitOptions = [
      { id: 'seconds', name: 'seconds' },
      { id: 'minutes', name: 'minutes' },
      { id: 'hours', name: 'hours' },
      { id: 'days', name: 'days' },
    ];

    this.rateLimitLimitByOptions = [
      { id: 'apiKey', name: 'API Key' },
      { id: 'ip', name: 'IP Address' },
    ];
  },

  uniqueSettingsId: computed(function() {
    return uniqueId('api_settings_');
  }),

  actions: {
    primaryRateLimitChange(selectedRateLimit) {
      let rateLimits = this.model.rateLimits;
      rateLimits.forEach(function(rateLimit) {
        if(rateLimit === selectedRateLimit) {
          rateLimit.set('responseHeaders', true);
        } else {
          rateLimit.set('responseHeaders', false);
        }
      });
    },

    addRateLimit() {
      let collection = this.model.rateLimits;
      collection.pushObject(this.store.createRecord('api/rate-limit'));
    },

    deleteRateLimit(rateLimit) {
      let collection = this.model.rateLimits;
      bootbox.confirm('Are you sure you want to remove this rate limit?', function(result) {
        if(result) {
          collection.removeObject(rateLimit);
        }
      });
    },
  },
});
