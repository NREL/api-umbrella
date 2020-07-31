import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  matcherType: [
    validator('presence', true),
  ],
  httpMethod: [
    validator('presence', true),
  ],
  frontendMatcher: [
    validator('presence', true),
  ],
  backendReplacement: [
    validator('presence', true),
  ],
});

export default Model.extend(Validations, {
  sortOrder: attr('number'),
  matcherType: attr(),
  httpMethod: attr(),
  frontendMatcher: attr(),
  backendReplacement: attr(),
}).reopenClass({
  validationClass: Validations,
});
