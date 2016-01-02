import Ember from 'ember';
import { Model, attr, belongsTo } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  id: attr(),
  apiKey: attr(),
  apiKeyHidesAt: attr(),
  apiKeyPreview: attr(),
  firstName: attr(),
  lastName: attr(),
  email: attr(),
  emailVerified: attr(),
  website: attr(),
  useDescription: attr(),
  registrationSource: attr(),
  termsAndConditions: attr(),
  sendWelcomeEmail: attr(),
  throttleByIp: attr(),
  roles: attr(),
  enabled: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),
  registrationIp: attr(),
  registrationUserAgent: attr(),
  registrationReferer: attr(),
  registrationOrigin: attr(),

  settings: belongsTo('Admin.ApiSettings', { key: 'settings', embedded: true }),

  validations: {
    firstName: {
      presence: true,
    },
    lastName: {
      presence: true,
    },
    email: {
      presence: true,
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
    if(this.get('throttleByIp') === undefined) {
      this.set('throttleByIp', false);
    }

    if(this.get('enabled') === undefined) {
      this.set('enabled', true);
    }

    if(!this.get('settings')) {
      this.set('settings', Admin.ApiSettings.create());
    }

    if(!this.get('registrationSource') && this.get('isNew')) {
      this.set('registrationSource', 'web_admin');
    }
  },

  rolesString: function(key, value) {
    // Setter
    if(arguments.length > 1) {
      var roles = value.split(',');
      this.set('roles', roles);
    }

    // Getter
    var rolesString = '';
    if(this.get('roles')) {
      rolesString = this.get('roles').join(',');
    }

    return rolesString;
  }.property('roles'),

  didSaveRecord: function() {
    // Clear the cached roles on save, so the list of available roles is always
    // correct for subsequent form renderings in this current session.
    Admin.ApiUserRole.clearCache();
  },
}).reopenClass({
  url: '/api-umbrella/v1/users',
  rootKey: 'user',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
