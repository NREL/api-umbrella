import Model, { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  username: validator('presence', true),
});

@classic
class Admin extends Model.extend(Validations) {
  @attr()
  username;

  @attr()
  password;

  @attr()
  passwordConfirmation;

  @attr()
  currentPassword;

  @attr()
  email;

  @attr('boolean')
  sendInviteEmail;

  @attr()
  name;

  @attr()
  notes;

  @attr()
  superuser;

  @attr({ defaultValue() { return [] } })
  groupIds;

  @attr()
  signInCount;

  @attr()
  currentSignInAt;

  @attr()
  lastSignInAt;

  @attr()
  currentSignInIp;

  @attr()
  lastSignInIp;

  @attr()
  currentSignInProvider;

  @attr()
  lastSignInProvider;

  @attr()
  authenticationToken;

  @attr()
  createdAt;

  @attr()
  updatedAt;

  @attr()
  creator;

  @attr()
  updater;
}

Admin.reopenClass({
  urlRoot: '/api-umbrella/v1/admins',
  singlePayloadKey: 'admin',
  arrayPayloadKey: 'data',
});

export default Admin;
