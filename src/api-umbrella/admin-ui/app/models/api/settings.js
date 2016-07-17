import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { hasMany } from 'ember-data/relationships';

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
    if(this.get('rateLimitMode') === undefined) {
      this.set('rateLimitMode', null);
    }

    // Make sure at least an empty object exists so the form builder can dive
    // into this section even when there's no pre-existing data.
    if(!this.get('errorTemplates')) {
      this.set('errorTemplates', Ember.Object.create({}));
    }

    if(!this.get('errorDataYamlStrings')) {
      this.set('errorDataYamlStrings', Ember.Object.create({}));
    }
  },

  requiredRolesString: Ember.computed('requiredRoles', {
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

  allowedIpsString: Ember.computed('allowedIps', {
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

  allowedReferersString: Ember.computed('allowedReferers', {
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

  passApiKey: Ember.computed('passApiKeyHeader', 'passApiKeyQueryParam', function() {
    let options = Ember.A([]);
    if(this.get('passApiKeyHeader')) {
      options.pushObject('header');
    }
    if(this.get('passApiKeyQueryParam')) {
      options.pushObject('param');
    }
    return options;
  }),

  passApiKeyDidChange: Ember.observer('passApiKey.@each', function() {
    var options = this.get('passApiKey');
    this.set('passApiKeyHeader', options.contains('header'));
    this.set('passApiKeyQueryParam', options.contains('param'));
  }),

  isRateLimitModeCustom: Ember.computed('rateLimitMode', function() {
    return (this.get('rateLimitMode') === 'custom');
  }),
});
