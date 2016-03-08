import { Model, attr } from 'ember-model';

export default Model.extend({
  id: attr(),
  sortOrder: attr(Number),
  matcherType: attr(),
  httpMethod: attr(),
  frontendMatcher: attr(),
  backendReplacement: attr(),
}).reopenClass({
  primaryKey: 'id',
  camelizeKeys: true,
});
