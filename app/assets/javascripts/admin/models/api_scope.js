Admin.ApiScope = Ember.Model.extend({
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

Admin.ApiScope.url = '/api-umbrella/v1/api_scopes';
Admin.ApiScope.rootKey = 'api_scope';
Admin.ApiScope.collectionKey = 'data';
Admin.ApiScope.primaryKey = 'id';
Admin.ApiScope.camelizeKeys = true;
Admin.ApiScope.adapter = Admin.APIUmbrellaRESTAdapter.create();
