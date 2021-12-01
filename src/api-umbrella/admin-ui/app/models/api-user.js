import { computed } from '@ember/object';
import Model, { attr, belongsTo } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';
import compact from 'lodash-es/compact';

const Validations = buildValidations({
  firstName: validator('presence', true),
  lastName: validator('presence', true),
  email: validator('presence', true),
});

@classic
class ApiUser extends Model.extend(Validations) {
  @attr()
  apiKey;

  @attr()
  apiKeyHidesAt;

  @attr()
  apiKeyPreview;

  @attr()
  firstName;

  @attr()
  lastName;

  @attr()
  email;

  @attr()
  emailVerified;

  @attr()
  website;

  @attr()
  useDescription;

  @attr()
  registrationSource;

  @attr()
  termsAndConditions;

  @attr()
  sendWelcomeEmail;

  @attr('boolean')
  throttleByIp;

  @attr()
  roles;

  @attr('boolean')
  enabled;

  @attr()
  createdAt;

  @attr()
  updatedAt;

  @attr()
  creator;

  @attr()
  updater;

  @attr()
  registrationIp;

  @attr()
  registrationUserAgent;

  @attr()
  registrationReferer;

  @attr()
  registrationOrigin;

  @belongsTo('api/settings', { async: false })
  settings;

  ready() {
    this.setDefaults();
  }

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
  }

  @computed('roles')
  get rolesString() {
    let rolesString = '';
    if(this.roles) {
      rolesString = this.roles.join(',');
    }
    return rolesString;
  }

  set rolesString(value) {
    let roles = compact(value.split(','));
    if(roles.length === 0) { roles = null; }
    this.set('roles', roles);
  }
}

ApiUser.reopenClass({
  urlRoot: '/api-umbrella/v1/users',
  singlePayloadKey: 'user',
  arrayPayloadKey: 'data',
});

export default ApiUser;
