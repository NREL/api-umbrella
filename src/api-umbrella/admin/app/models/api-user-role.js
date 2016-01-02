Admin.ApiUserRole = Ember.Model.extend({
  id: Ember.attr(),
});

Admin.ApiUserRole.url = '/api-umbrella/v1/user_roles';
Admin.ApiUserRole.rootKey = 'user_roles';
Admin.ApiUserRole.collectionKey = 'user_roles';
Admin.ApiUserRole.primaryKey = 'id';
Admin.ApiUserRole.camelizeKeys = true;
Admin.ApiUserRole.adapter = Admin.APIUmbrellaRESTAdapter.create();
