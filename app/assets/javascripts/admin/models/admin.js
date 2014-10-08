Admin.Admin = Ember.Model.extend({
  id: Ember.attr(),
  username: Ember.attr(),
  email: Ember.attr(),
  name: Ember.attr(),
  superuser: Ember.attr(),
  groupIds: Ember.attr(),
  signInCount: Ember.attr(),
  lastSignInAt: Ember.attr(),
  lastSignInIp: Ember.attr(),
  lastSignInProvider: Ember.attr(),
  authenticationToken: Ember.attr(),
  createdAt: Ember.attr(),
  updatedAt: Ember.attr(),
  creator: Ember.attr(),
  updater: Ember.attr(),
});

Admin.Admin.url = '/api-umbrella/v1/admins';
Admin.Admin.rootKey = 'admin';
Admin.Admin.collectionKey = 'data';
Admin.Admin.primaryKey = 'id';
Admin.Admin.camelizeKeys = true;
Admin.Admin.adapter = Admin.APIUmbrellaRESTAdapter.create();
