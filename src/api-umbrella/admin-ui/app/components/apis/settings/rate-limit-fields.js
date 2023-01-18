// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { inject } from '@ember/service';
import { tagName } from "@ember-decorators/component";
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import uniqueId from 'lodash-es/uniqueId';
import without from 'lodash-es/without';

@tagName("")
@classic
export default class RateLimitFields extends Component {
  @inject()
  store;

  rateLimitModeOptions = [
    { id: null, name: 'Default rate limits' },
    { id: 'custom', name: 'Custom rate limits' },
    { id: 'unlimited', name: 'Unlimited requests' },
  ];

  rateLimitDurationUnitOptions = [
    { id: 'seconds', name: 'seconds' },
    { id: 'minutes', name: 'minutes' },
    { id: 'hours', name: 'hours' },
    { id: 'days', name: 'days' },
  ];

  rateLimitLimitByOptions = [
    { id: 'apiKey', name: 'API Key' },
    { id: 'ip', name: 'IP Address' },
  ];

  @computed
  get uniqueSettingsId() {
    return uniqueId('api_settings_');
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
    collection.push(this.store.createRecord('api/rate-limit'));
  }

  @action
  deleteRateLimit(rateLimit) {
    bootbox.confirm('Are you sure you want to remove this rate limit?', (result) => {
      if(result) {
        let collection = without(this.model.rateLimits, rateLimit);
        this.model.set('rateLimits', collection);
      }
    });
  }
}
