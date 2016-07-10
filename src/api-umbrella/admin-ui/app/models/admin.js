import Model from 'ember-data/model';
import attr from 'ember-data/attr';

export default Model.extend({
  username: attr(),
  email: attr(),
  name: attr(),
  superuser: attr(),
  groupIds: attr({ defaultValue() { return [] } }),
  signInCount: attr(),
  lastSignInAt: attr(),
  lastSignInIp: attr(),
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
