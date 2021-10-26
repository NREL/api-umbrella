import Model, { attr, belongsTo } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

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
  metadataYamlString: attr(),

  settings: belongsTo('api/settings', { async: false }),

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
