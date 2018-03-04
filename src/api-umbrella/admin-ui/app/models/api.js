import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import I18n from 'npm:i18n-js';
import { computed } from '@ember/object';

const Validations = buildValidations({
  name: validator('presence', true),
  frontendHost: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  backendHost: [
    validator('presence', {
      presence: true,
      disabled: computed('model.frontendHost', function() {
        return (this.get('model.frontendHost') && this.get('model.frontendHost')[0] === '*');
      }),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
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
    if(!this.get('settings')) {
      this.set('settings', this.get('store').createRecord('api/settings'));
    }
  },

  exampleIncomingUrlRoot: computed('frontendHost', function() {
    return 'https://' + (this.get('frontendHost') || '');
  }),

  exampleOutgoingUrlRoot: computed('backendProtocol', 'backendHost', 'fontendHost', function() {
    return this.get('backendProtocol') + '://' + (this.get('backendHost') || this.get('frontendHost') || '');
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/apis',
  singlePayloadKey: 'api',
  arrayPayloadKey: 'data',
});
