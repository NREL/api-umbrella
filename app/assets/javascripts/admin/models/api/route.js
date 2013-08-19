Admin.ApiRoute = Ember.Model.extend({
  matcher: Ember.attr(),
  httpMethod: Ember.attr(),
  from: Ember.attr(),
  to: Ember.attr(),
});

Admin.ApiRoute.camelizeKeys = true;
