import Model, { attr } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  matcherType: [
    validator('presence', {
      presence: true,
      description: t('Matcher Type'),
    }),
  ],
  httpMethod: [
    validator('presence', {
      presence: true,
      description: t('HTTP Method'),
    }),
  ],
  frontendMatcher: [
    validator('presence', {
      presence: true,
      description: t('Frontend Matcher'),
    }),
  ],
  backendReplacement: [
    validator('presence', {
      presence: true,
      description: t('Backend Replacement'),
    }),
  ],
});

class Rewrite extends Model.extend(Validations) {
  static validationClass = Validations;

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

export default Rewrite;
