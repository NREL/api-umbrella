import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

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

export default Model.extend(Validations, {
  sortOrder: attr('number'),
  matcherType: attr(),
  httpMethod: attr(),
  frontendMatcher: attr(),
  backendReplacement: attr(),
}).reopenClass({
  validationClass: Validations,
});
