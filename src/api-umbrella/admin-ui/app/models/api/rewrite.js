import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
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

export default DS.Model.extend(Validations, {
  sortOrder: DS.attr('number'),
  matcherType: DS.attr(),
  httpMethod: DS.attr(),
  frontendMatcher: DS.attr(),
  backendReplacement: DS.attr(),
}).reopenClass({
  validationClass: Validations,
});
