import { Model, attr } from 'ember-model';

export default Model.extend({
  id: attr(),
}).reopenClass({
  url: '/api-umbrella/v1/user_roles',
  rootKey: 'user_roles',
  collectionKey: 'user_roles',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
