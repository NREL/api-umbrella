import DS from 'ember-data';

export default DS.Model.extend({
  sortOrder: DS.attr('number'),
  matcherType: DS.attr(),
  httpMethod: DS.attr(),
  frontendMatcher: DS.attr(),
  backendReplacement: DS.attr(),
});
