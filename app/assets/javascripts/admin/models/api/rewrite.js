Admin.ApiRewrite = Ember.Model.extend({
  _id: Ember.attr(),
  sortOrder: Ember.attr(Number),
  matcher: Ember.attr(),
  httpMethod: Ember.attr(),
  from: Ember.attr(),
  to: Ember.attr(),
});

Admin.ApiRewrite.camelizeKeys = true;
