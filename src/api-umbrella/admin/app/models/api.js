import Ember from 'ember';
import { Model, attr, belongsTo, hasMany } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  name: attr(),
  sortOrder: attr('number'),
  backendProtocol: attr(),
  frontendHost: attr(),
  backendHost: attr(),
  balanceAlgorithm: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),

  servers: hasMany('api/server', { async: false }),
  urlMatches: hasMany('api/url-match', { async: false }),
  settings: belongsTo('api/settings', { async: false }),
  subSettings: hasMany('api/sub-settings', { async: false }),
  rewrites: hasMany('api/rewrites', { async: false }),

  validations: {
    name: {
      presence: true,
    },
    frontendHost: {
      presence: true,
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: I18n.t('errors.messages.invalid_host_format'),
      },
    },
    backendHost: {
      presence: {
        unless(object) {
          return (object.get('frontendHost') && object.get('frontendHost')[0] === '*');
        },
      },
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: I18n.t('errors.messages.invalid_host_format'),
        if(object) {
          return !!object.get('backendHost');
        },
      },
    },
  },

  init() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults() {
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

  didUpdate() {
    // Clear the cached roles on save, so the list of available roles is always
    // correct for subsequent form renderings in this current session.
    this.get('store').unloadAll('api-user-role');
  },

  didCreate() {
    this.didUpdate();
  },
}).reopenClass({
  url: '/api-umbrella/v1/apis',
  rootKey: 'api',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
