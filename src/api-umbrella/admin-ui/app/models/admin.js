import DS from 'ember-data';
import { validator, buildValidations } from 'ember-cp-validations';

const Validations = buildValidations({
  username: validator('presence', true),
});

export default DS.Model.extend(Validations, {
  username: DS.attr(),
  email: DS.attr(),
  name: DS.attr(),
  superuser: DS.attr(),
  groupIds: DS.attr({ defaultValue() { return [] } }),
  signInCount: DS.attr(),
  lastSignInAt: DS.attr(),
  lastSignInIp: DS.attr(),
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
