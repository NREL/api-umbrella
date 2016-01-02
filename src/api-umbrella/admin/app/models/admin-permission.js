Admin.AdminPermission = Ember.Model.extend({
  id: Ember.attr(),
  name: Ember.attr()
});

Admin.AdminPermission.url = '/api-umbrella/v1/admin_permissions';
Admin.AdminPermission.rootKey = 'admin_permission';
Admin.AdminPermission.collectionKey = 'admin_permissions';
Admin.AdminPermission.primaryKey = 'id';
Admin.AdminPermission.camelizeKeys = true;
Admin.AdminPermission.adapter = Admin.APIUmbrellaRESTAdapter.create();
