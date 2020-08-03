import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';
import usernameLabel from 'api-umbrella-admin-ui/utils/username-label'

const Validations = buildValidations({
  username: validator('presence', {
    presence: true,
    description: usernameLabel(),
  }),
});

export default Model.extend(Validations, {
  username: attr(),
  password: attr(),
  passwordConfirmation: attr(),
  currentPassword: attr(),
  email: attr(),
  sendInviteEmail: attr('boolean'),
  name: attr(),
  notes: attr(),
  superuser: attr(),
  groupIds: attr({ defaultValue() { return [] } }),
  signInCount: attr(),
  currentSignInAt: attr(),
  lastSignInAt: attr(),
  currentSignInIp: attr(),
  lastSignInIp: attr(),
  currentSignInProvider: attr(),
  lastSignInProvider: attr(),
  authenticationToken: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admins',
  singlePayloadKey: 'admin',
  arrayPayloadKey: 'data',
});
