import Model, { attr, belongsTo, hasMany } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

import { computed } from '@ember/object';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
  name: validator('presence', {
    presence: true,
    description: t('Name'),
  }),
  frontendHost: [
    validator('presence', {
      presence: true,
      description: t('Frontend Host'),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Frontend Host'),
      message: t('must be in the format of "example.com"'),
    }),
  ],
  backendHost: [
    validator('presence', {
      presence: true,
      description: t('Frontend Host'),
      disabled: computed('model.frontendHost', function() {
        return (this.model.frontendHost && this.model.frontendHost[0] === '*');
      }),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Backend Host'),
      message: t('must be in the format of "example.com"'),
      disabled: computed.not('model.backendHost'),
    }),
  ],
});

export default Model.extend(Validations, {
  name: attr(),
  backendProtocol: attr('string', { defaultValue: 'http' }),
  frontendHost: attr(),
  backendHost: attr(),
  balanceAlgorithm: attr('string', { defaultValue: 'least_conn' }),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),
  organizationName: attr(),
  statusDescription: attr(),
  rootApiScope: attr(),
  apiScopes: attr(),
  adminGroups: attr(),

  servers: hasMany('api/server', { async: false }),
  urlMatches: hasMany('api/url-match', { async: false }),
  settings: belongsTo('api/settings', { async: false }),
  subSettings: hasMany('api/sub-settings', { async: false }),
  rewrites: hasMany('api/rewrites', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }
  },

  exampleIncomingUrlRoot: computed('frontendHost', function() {
    return 'https://' + (this.frontendHost || '');
  }),

  exampleOutgoingUrlRoot: computed('backendHost', 'backendProtocol', 'fontendHost', 'frontendHost', function() {
    return this.backendProtocol + '://' + (this.backendHost || this.frontendHost || '');
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/apis',
  singlePayloadKey: 'api',
  arrayPayloadKey: 'data',
});
