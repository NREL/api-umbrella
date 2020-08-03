// eslint-disable-next-line ember/no-observers
import EmberObject, { computed, observer } from '@ember/object';
import Model, { attr, hasMany } from '@ember-data/model';

import { A } from '@ember/array';
import compact from 'lodash-es/compact';

export default Model.extend({
  appendQueryString: attr(),
  headersString: attr(),
  httpBasicAuth: attr(),
  requireHttps: attr(),
  disableApiKey: attr(),
  apiKeyVerificationLevel: attr(),
  requiredRoles: attr(),
  requiredRolesOverride: attr(),
  allowedIps: attr(),
  allowedReferers: attr(),
  rateLimitMode: attr(),
  anonymousRateLimitBehavior: attr(),
  authenticatedRateLimitBehavior: attr(),
  passApiKeyHeader: attr(),
  passApiKeyQueryParam: attr(),
  defaultResponseHeadersString: attr(),
  overrideResponseHeadersString: attr(),
  errorTemplates: attr(),
  errorDataYamlStrings: attr(),

  rateLimits: hasMany('api/rate-limit', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(this.requireHttps === undefined) {
      this.set('requireHttps', null);
    }

    if(this.disableApiKey === undefined) {
      this.set('disableApiKey', null);
    }

    if(this.apiKeyVerificationLevel === undefined) {
      this.set('apiKeyVerificationLevel', null);
    }

    if(this.rateLimitMode === undefined) {
      this.set('rateLimitMode', null);
    }

    // Make sure at least an empty object exists so the form builder can dive
    // into this section even when there's no pre-existing data.
    if(!this.errorTemplates) {
      this.set('errorTemplates', EmberObject.create({}));
    }

    if(!this.errorDataYamlStrings) {
      this.set('errorDataYamlStrings', EmberObject.create({}));
    }
  },

  requiredRolesString: computed('requiredRoles', {
    get() {
      let rolesString = '';
      if(this.requiredRoles) {
        rolesString = this.requiredRoles.join(',');
      }
      return rolesString;
    },
    set(key, value) {
      let roles = compact(value.split(','));
      if(roles.length === 0) { roles = null; }
      this.set('requiredRoles', roles);
      return value;
    },
  }),

  allowedIpsString: computed('allowedIps', {
    get() {
      let allowedIpsString = '';
      if(this.allowedIps) {
        allowedIpsString = this.allowedIps.join('\n');
      }
      return allowedIpsString;
    },
    set(key, value) {
      let ips = compact(value.split(/[\r\n]+/));
      if(ips.length === 0) { ips = null; }
      this.set('allowedIps', ips);
      return value;
    },
  }),

  allowedReferersString: computed('allowedReferers', {
    get() {
      let allowedReferersString = '';
      if(this.allowedReferers) {
        allowedReferersString = this.allowedReferers.join('\n');
      }
      return allowedReferersString;
    },
    set(key, value) {
      let referers = compact(value.split(/[\r\n]+/));
      if(referers.length === 0) { referers = null; }
      this.set('allowedReferers', referers);
      return value;
    },
  }),

  passApiKey: computed('passApiKeyHeader', 'passApiKeyQueryParam', function() {
    let options = A([]);
    if(this.passApiKeyHeader) {
      options.pushObject('header');
    }
    if(this.passApiKeyQueryParam) {
      options.pushObject('param');
    }
    return options;
  }),

  // eslint-disable-next-line ember/no-observers
  passApiKeyDidChange: observer('passApiKey.@each', function() {
    let options = this.passApiKey;
    this.set('passApiKeyHeader', options.includes('header'));
    this.set('passApiKeyQueryParam', options.includes('param'));
  }),

  isRateLimitModeCustom: computed.equal('rateLimitMode', 'custom'),
});
