import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
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
        return (this.get('model.frontendHost') && this.get('model.frontendHost')[0] === '*');
      }),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      description: t('Backend Host'),
      message: t('must be in the format of "example.com"'),
      disabled: computed('model.backendHost', function() {
        return !this.get('model.backendHost');
      }),
    }),
  ],
});

export default DS.Model.extend(Validations, {
  name: DS.attr(),
  sortOrder: DS.attr('number'),
  backendProtocol: DS.attr('string', { defaultValue: 'http' }),
  frontendHost: DS.attr(),
  backendHost: DS.attr(),
  balanceAlgorithm: DS.attr('string', { defaultValue: 'least_conn' }),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),

  servers: DS.hasMany('api/server', { async: false }),
  urlMatches: DS.hasMany('api/url-match', { async: false }),
  settings: DS.belongsTo('api/settings', { async: false }),
  subSettings: DS.hasMany('api/sub-settings', { async: false }),
  rewrites: DS.hasMany('api/rewrites', { async: false }),

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

  exampleOutgoingUrlRoot: computed('backendProtocol', 'backendHost', 'fontendHost', function() {
    return this.backendProtocol + '://' + (this.backendHost || this.frontendHost || '');
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/apis',
  singlePayloadKey: 'api',
  arrayPayloadKey: 'data',
});
