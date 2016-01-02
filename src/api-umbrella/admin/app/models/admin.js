import { Model, attr } from 'ember-model';

export default Model.extend({
  id: attr(),
  username: attr(),
  email: attr(),
  name: attr(),
  superuser: attr(),
  groupIds: attr(),
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
  url: '/api-umbrella/v1/admins',
  rootKey: 'admin',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
