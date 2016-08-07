import Ember from 'ember';
import Model from 'ember-data/model';
import UnloadAfterSave from 'api-umbrella-admin/mixins/unload-after-save';
import attr from 'ember-data/attr';
import { belongsTo, hasMany } from 'ember-data/relationships';
import { validator, buildValidations } from 'ember-cp-validations';

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
      disabled: Ember.computed('model.frontendHost', function() {
        return (this.get('model.frontendHost') && this.get('model.frontendHost')[0] === '*');
      }),
    }),
    validator('format', {
      regex: CommonValidations.host_format_with_wildcard,
      message: I18n.t('errors.messages.invalid_host_format'),
      disabled: Ember.computed('model.backendHost', function() {
        return !this.get('model.backendHost');
      }),
    }),
  ],
});

export default Model.extend(Validations, UnloadAfterSave, {
  name: attr(),
  sortOrder: attr('number'),
  backendProtocol: attr('string', { defaultValue: 'http' }),
  frontendHost: attr(),
  backendHost: attr(),
  balanceAlgorithm: attr('string', { defaultValue: 'least_conn' }),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),

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
    if(!this.get('settings')) {
      this.set('settings', this.get('store').createRecord('api/settings'));
    }
  },

  exampleIncomingUrlRoot: Ember.computed('frontendHost', function() {
    return 'http://' + (this.get('frontendHost') || '');
  }),

  exampleOutgoingUrlRoot: Ember.computed('backendHost', function() {
    return 'http://' + (this.get('backendHost') || this.get('frontendHost') || '');
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/apis',
  singlePayloadKey: 'api',
  arrayPayloadKey: 'data',
});
