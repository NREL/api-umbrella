Admin.AdminGroup = Ember.Model.extend({
  id: Ember.attr(),
  name: Ember.attr(),
  access: Ember.attr(),
  createdAt: Ember.attr(),
  updatedAt: Ember.attr(),
  creator: Ember.attr(),
  updater: Ember.attr(),

  scope: Ember.belongsTo('Admin.AdminScope', { key: 'scope_id' }),
});

Admin.AdminGroup.url = "/api-umbrella/v1/admin_groups";
Admin.AdminGroup.rootKey = "admin_group";
Admin.AdminGroup.collectionKey = "data";
Admin.AdminGroup.primaryKey = "id";
Admin.AdminGroup.camelizeKeys = true;
Admin.AdminGroup.adapter = Admin.APIUmbrellaRESTAdapter.create();
