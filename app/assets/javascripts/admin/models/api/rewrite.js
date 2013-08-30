Admin.ApiRewrite = Ember.Model.extend({
  _id: Ember.attr(),
  matcher: Ember.attr(),
  httpMethod: Ember.attr(),
  from: Ember.attr(),
  to: Ember.attr(),
});

Admin.ApiRewrite.camelizeKeys = true;
