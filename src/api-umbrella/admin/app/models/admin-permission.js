import { Model, attr } from 'ember-model';

export default Model.extend({
  id: attr(),
  name: attr()
}).reopenClass({
  url: '/api-umbrella/v1/admin_permissions',
  rootKey: 'admin_permission',
  collectionKey: 'admin_permissions',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
