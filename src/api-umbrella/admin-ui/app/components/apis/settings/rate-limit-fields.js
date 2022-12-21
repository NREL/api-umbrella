// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { inject } from '@ember/service';
import { tagName } from "@ember-decorators/component";
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import uniqueId from 'lodash-es/uniqueId';

@tagName("")
@classic
export default class RateLimitFields extends Component {
  @inject()
  store;

  init() {
    super.init(...arguments);

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
  }

  get uniqueSettingsId() {
    if(!this.uniqueSettingsIdValue) {
      this.uniqueSettingsIdValue = uniqueId('api_settings_');
    }

    return this.uniqueSettingsIdValue;
  }

  @action
  primaryRateLimitChange(selectedRateLimit) {
    let rateLimits = this.model.rateLimits;
    rateLimits.forEach(function(rateLimit) {
      if(rateLimit === selectedRateLimit) {
        rateLimit.set('responseHeaders', true);
      } else {
        rateLimit.set('responseHeaders', false);
      }
    });
  }

  @action
  addRateLimit() {
    let collection = this.model.rateLimits;
    collection.pushObject(this.store.createRecord('api/rate-limit'));
  }

  @action
  deleteRateLimit(rateLimit) {
    let collection = this.model.rateLimits;
    bootbox.confirm('Are you sure you want to remove this rate limit?', function(result) {
      if(result) {
        collection.removeObject(rateLimit);
      }
    });
  }
}
