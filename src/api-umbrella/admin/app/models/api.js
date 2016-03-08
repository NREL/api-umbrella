import Ember from 'ember';
import { Model, attr, belongsTo, hasMany } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  name: attr(),
  sortOrder: attr(Number),
  backendProtocol: attr(),
  frontendHost: attr(),
  backendHost: attr(),
  balanceAlgorithm: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),

  servers: hasMany('Admin.ApiServer', { key: 'servers', embedded: true }),
  urlMatches: hasMany('Admin.ApiUrlMatch', { key: 'url_matches', embedded: true }),
  settings: belongsTo('Admin.ApiSettings', { key: 'settings', embedded: true }),
  subSettings: hasMany('Admin.ApiSubSettings', { key: 'sub_settings', embedded: true }),
  rewrites: hasMany('Admin.ApiRewrite', { key: 'rewrites', embedded: true }),

  validations: {
    name: {
      presence: true,
    },
    frontendHost: {
      presence: true,
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: polyglot.t('errors.messages.invalid_host_format'),
      },
    },
    backendHost: {
      presence: {
        unless: function(object) {
          return (object.get('frontendHost') && object.get('frontendHost')[0] === '*');
        },
      },
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: polyglot.t('errors.messages.invalid_host_format'),
        if: function(object) {
          return !!object.get('backendHost');
        },
      },
    },
  },

  init: function() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults: function() {
    if(!this.get('settings')) {
      this.set('settings', Admin.ApiSettings.create());
    }
  },

  exampleIncomingUrlRoot: function() {
    return 'http://' + (this.get('frontendHost') || '');
  }.property('frontendHost'),

  exampleOutgoingUrlRoot: function() {
    return 'http://' + (this.get('backendHost') || this.get('frontendHost') || '');
  }.property('backendHost'),

  didSaveRecord: function() {
    // Clear the cached roles on save, so the list of available roles is always
    // correct for subsequent form renderings in this current session.
    Admin.ApiUserRole.clearCache();
  },
}).reopenClass({
  url: '/api-umbrella/v1/apis',
  rootKey: 'api',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
