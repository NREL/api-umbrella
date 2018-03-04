import EmberObject, { computed, observer } from '@ember/object';

import { A } from '@ember/array';
import DS from 'ember-data';

export default DS.Model.extend({
  appendQueryString: DS.attr(),
  headersString: DS.attr(),
  httpBasicAuth: DS.attr(),
  requireHttps: DS.attr(),
  disableApiKey: DS.attr(),
  apiKeyVerificationLevel: DS.attr(),
  requiredRoles: DS.attr(),
  requiredRolesOverride: DS.attr(),
  allowedIps: DS.attr(),
  allowedReferers: DS.attr(),
  rateLimitMode: DS.attr(),
  anonymousRateLimitBehavior: DS.attr(),
  authenticatedRateLimitBehavior: DS.attr(),
  passApiKeyHeader: DS.attr(),
  passApiKeyQueryParam: DS.attr(),
  defaultResponseHeadersString: DS.attr(),
  overrideResponseHeadersString: DS.attr(),
  errorTemplates: DS.attr(),
  errorDataYamlStrings: DS.attr(),

  rateLimits: DS.hasMany('api/rate-limit', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(this.get('rateLimitMode') === undefined) {
      this.set('rateLimitMode', null);
    }

    // Make sure at least an empty object exists so the form builder can dive
    // into this section even when there's no pre-existing data.
    if(!this.get('errorTemplates')) {
      this.set('errorTemplates', EmberObject.create({}));
    }

    if(!this.get('errorDataYamlStrings')) {
      this.set('errorDataYamlStrings', EmberObject.create({}));
    }
  },

  requiredRolesString: computed('requiredRoles', {
    get() {
      let rolesString = '';
      if(this.get('requiredRoles')) {
        rolesString = this.get('requiredRoles').join(',');
      }
      return rolesString;
    },
    set(key, value) {
      let roles = _.compact(value.split(','));
      if(roles.length === 0) { roles = null; }
      this.set('requiredRoles', roles);
      return value;
    },
  }),

  allowedIpsString: computed('allowedIps', {
    get() {
      let allowedIpsString = '';
      if(this.get('allowedIps')) {
        allowedIpsString = this.get('allowedIps').join('\n');
      }
      return allowedIpsString;
    },
    set(key, value) {
      let ips = _.compact(value.split(/[\r\n]+/));
      if(ips.length === 0) { ips = null; }
      this.set('allowedIps', ips);
      return value;
    },
  }),

  allowedReferersString: computed('allowedReferers', {
    get() {
      let allowedReferersString = '';
      if(this.get('allowedReferers')) {
        allowedReferersString = this.get('allowedReferers').join('\n');
      }
      return allowedReferersString;
    },
    set(key, value) {
      let referers = _.compact(value.split(/[\r\n]+/));
      if(referers.length === 0) { referers = null; }
      this.set('allowedReferers', referers);
      return value;
    },
  }),

  passApiKey: computed('passApiKeyHeader', 'passApiKeyQueryParam', function() {
    let options = A([]);
    if(this.get('passApiKeyHeader')) {
      options.pushObject('header');
    }
    if(this.get('passApiKeyQueryParam')) {
      options.pushObject('param');
    }
    return options;
  }),

  passApiKeyDidChange: observer('passApiKey.@each', function() {
    let options = this.get('passApiKey');
    this.set('passApiKeyHeader', options.includes('header'));
    this.set('passApiKeyQueryParam', options.includes('param'));
  }),

  isRateLimitModeCustom: computed('rateLimitMode', function() {
    return (this.get('rateLimitMode') === 'custom');
  }),
});
