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

  requiredRolesString: function(key, value) {
    // Setter
    if(arguments.length > 1) {
      let roles = _.compact(value.split(','));
      if(roles.length === 0) { roles = null; }
      this.set('requiredRoles', roles);
    }

    // Getter
    let rolesString = '';
    if(this.get('requiredRoles')) {
      rolesString = this.get('requiredRoles').join(',');
    }

    return rolesString;
  }.property('requiredRoles'),

  allowedIpsString: function(key, value) {
    // Setter
    if(arguments.length > 1) {
      let ips = _.compact(value.split(/[\r\n]+/));
      if(ips.length === 0) { ips = null; }
      this.set('allowedIps', ips);
    }

    // Getter
    let allowedIpsString = '';
    if(this.get('allowedIps')) {
      allowedIpsString = this.get('allowedIps').join('\n');
    }

    return allowedIpsString;
  }.property('allowedIps'),

  allowedReferersString: function(key, value) {
    // Setter
    if(arguments.length > 1) {
      let referers = _.compact(value.split(/[\r\n]+/));
      if(referers.length === 0) { referers = null; }
      this.set('allowedReferers', referers);
    }

    // Getter
    let allowedReferersString = '';
    if(this.get('allowedReferers')) {
      allowedReferersString = this.get('allowedReferers').join('\n');
    }

    return allowedReferersString;
  }.property('allowedReferers'),

  isRateLimitModeCustom: function() {
    return (this.get('rateLimitMode') === 'custom');
  }.property('rateLimitMode'),
});
