Admin.ApiRewrite = Ember.Model.extend({
  matcher: Ember.attr(),
  httpMethod: Ember.attr(),
  from: Ember.attr(),
  to: Ember.attr(),
});

Admin.ApiRewrite.camelizeKeys = true;
