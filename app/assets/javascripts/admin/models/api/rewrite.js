Admin.ApiRewrite = Ember.Model.extend({
  _id: Ember.attr(),
  sortOrder: Ember.attr(Number),
  matcherType: Ember.attr(),
  httpMethod: Ember.attr(),
  frontendMatcher: Ember.attr(),
  backendReplacement: Ember.attr(),
});

Admin.ApiRewrite.camelizeKeys = true;
