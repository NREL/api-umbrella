Admin.ApiRewrite = Ember.Model.extend({
  id: Ember.attr(),
  sortOrder: Ember.attr(Number),
  matcherType: Ember.attr(),
  httpMethod: Ember.attr(),
  frontendMatcher: Ember.attr(),
  backendReplacement: Ember.attr(),
});

Admin.ApiRewrite.primaryKey = 'id';
Admin.ApiRewrite.camelizeKeys = true;
