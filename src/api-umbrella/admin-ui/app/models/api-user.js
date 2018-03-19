import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import { computed } from '@ember/object';

const Validations = buildValidations({
  firstName: validator('presence', true),
  lastName: validator('presence', true),
  email: validator('presence', true),
});

export default DS.Model.extend(Validations, {
  apiKey: DS.attr(),
  apiKeyHidesAt: DS.attr(),
  apiKeyPreview: DS.attr(),
  firstName: DS.attr(),
  lastName: DS.attr(),
  email: DS.attr(),
  emailVerified: DS.attr(),
  website: DS.attr(),
  useDescription: DS.attr(),
  registrationSource: DS.attr(),
  termsAndConditions: DS.attr(),
  sendWelcomeEmail: DS.attr(),
  throttleByIp: DS.attr('boolean'),
  roles: DS.attr(),
  enabled: DS.attr('boolean'),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),
  registrationIp: DS.attr(),
  registrationUserAgent: DS.attr(),
  registrationReferer: DS.attr(),
  registrationOrigin: DS.attr(),

  settings: DS.belongsTo('api/settings', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(this.get('throttleByIp') === undefined) {
      this.set('throttleByIp', false);
    }

    if(this.get('enabled') === undefined) {
      this.set('enabled', true);
    }

    if(!this.get('settings')) {
      this.set('settings', this.get('store').createRecord('api/settings'));
    }

    if(!this.get('registrationSource') && this.get('isNew')) {
      this.set('registrationSource', 'web_admin');
    }
  },

  rolesString: computed('roles', {
    get() {
      let rolesString = '';
      if(this.get('roles')) {
        rolesString = this.get('roles').join(',');
      }
      return rolesString;
    },
    set(key, value) {
      let roles = _.compact(value.split(','));
      if(roles.length === 0) { roles = null; }
      this.set('roles', roles);
      return value;
    },
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/users',
  singlePayloadKey: 'user',
  arrayPayloadKey: 'data',
});
