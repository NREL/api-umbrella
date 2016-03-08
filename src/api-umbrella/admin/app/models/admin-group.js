import Ember from 'ember';
import { Model, attr } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  id: attr(),
  name: attr(),
  apiScopeIds: attr(),
  permissionIds: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),

  validations: {
    name: {
      presence: true,
    },
  },
}).reopenClass({
  url: '/api-umbrella/v1/admin_groups',
  rootKey: 'admin_group',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
