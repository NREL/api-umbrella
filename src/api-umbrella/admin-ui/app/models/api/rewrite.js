import Model, { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';
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

@classic
class Rewrite extends Model.extend(Validations) {
  @attr('number')
  sortOrder;

  @attr()
  matcherType;

  @attr()
  httpMethod;

  @attr()
  frontendMatcher;

  @attr()
  backendReplacement;
}

Rewrite.reopenClass({
  validationClass: Validations,
});

export default Rewrite;
