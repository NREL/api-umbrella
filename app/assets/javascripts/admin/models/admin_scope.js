Admin.AdminScope = Ember.Model.extend({
  id: Ember.attr(),
  name: Ember.attr(),
  host: Ember.attr(),
  pathPrefix: Ember.attr(),
  createdAt: Ember.attr(),
  updatedAt: Ember.attr(),
  creator: Ember.attr(),
  updater: Ember.attr(),

  displayName: function() {
    return this.get('name') + ' - ' + this.get('host') + this.get('pathPrefix');
  }.property('name', 'host', 'pathPrefix')
});

Admin.AdminScope.url = "/api-umbrella/v1/admin_scopes";
Admin.AdminScope.rootKey = "admin_scope";
Admin.AdminScope.collectionKey = "data";
Admin.AdminScope.primaryKey = "id";
Admin.AdminScope.camelizeKeys = true;
Admin.AdminScope.adapter = Admin.APIUmbrellaRESTAdapter.create();
