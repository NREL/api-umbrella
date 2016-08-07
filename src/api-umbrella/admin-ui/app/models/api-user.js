import Ember from 'ember';
import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { belongsTo } from 'ember-data/relationships';
import { validator, buildValidations } from 'ember-cp-validations';

const Validations = buildValidations({
  firstName: validator('presence', true),
  lastName: validator('presence', true),
  email: validator('presence', true),
});

export default Model.extend(Validations, {
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
  throttleByIp: attr('boolean'),
  roles: attr(),
  enabled: attr('boolean'),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),
  registrationIp: attr(),
  registrationUserAgent: attr(),
  registrationReferer: attr(),
  registrationOrigin: attr(),

  settings: belongsTo('api/settings', { async: false }),

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

  rolesString: Ember.computed('roles', {
    get() {
      let rolesString = '';
      if(this.get('roles')) {
        rolesString = this.get('roles').join(',');
      }
      return rolesString;
    },
    set(key, value) {
      let roles = value.split(',');
      this.set('roles', roles);
      return value;
    },
  }),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/users',
  singlePayloadKey: 'user',
  arrayPayloadKey: 'data',
});
