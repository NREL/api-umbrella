import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';

const Validations = buildValidations({
  username: validator('presence', true),
});

export default DS.Model.extend(Validations, {
  username: DS.attr(),
  password: DS.attr(),
  passwordConfirmation: DS.attr(),
  currentPassword: DS.attr(),
  email: DS.attr(),
  sendInviteEmail: DS.attr('boolean'),
  name: DS.attr(),
  notes: DS.attr(),
  superuser: DS.attr(),
  groupIds: DS.attr({ defaultValue() { return [] } }),
  signInCount: DS.attr(),
  currentSignInAt: DS.attr(),
  lastSignInAt: DS.attr(),
  currentSignInIp: DS.attr(),
  lastSignInIp: DS.attr(),
  currentSignInProvider: DS.attr(),
  lastSignInProvider: DS.attr(),
  authenticationToken: DS.attr(),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admins',
  singlePayloadKey: 'admin',
  arrayPayloadKey: 'data',
});
