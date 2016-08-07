import Model from 'ember-data/model';
import attr from 'ember-data/attr';

export default Model.extend({
  sortOrder: attr('number'),
  matcherType: attr(),
  httpMethod: attr(),
  frontendMatcher: attr(),
  backendReplacement: attr(),
});
