import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import compact from 'lodash-es/compact';
import { computed } from '@ember/object';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
  firstName: validator('presence', {
    presence: true,
    description: t('First Name'),
  }),
  lastName: validator('presence', {
    presence: true,
    description: t('Last Name'),
  }),
  email: validator('presence', {
    presence: true,
    description: t('Email'),
  }),
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
    if(this.throttleByIp === undefined) {
      this.set('throttleByIp', false);
    }

    if(this.enabled === undefined) {
      this.set('enabled', true);
    }

    if(!this.settings) {
      this.set('settings', this.store.createRecord('api/settings'));
    }

    if(!this.registrationSource && this.isNew) {
      this.set('registrationSource', 'web_admin');
    }
  },

  rolesString: computed('roles', {
    get() {
      let rolesString = '';
      if(this.roles) {
        rolesString = this.roles.join(',');
      }
      return rolesString;
    },
    set(key, value) {
      let roles = compact(value.split(','));
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
