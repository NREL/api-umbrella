import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
import { computed } from '@ember/object';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
  frontendPrefix: [
    validator('presence', {
      presence: true,
      description: t('Frontend Prefix'),
    }),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      description: t('Frontend Prefix'),
      message: t('must start with "/"'),
    }),
  ],
  backendPrefix: [
    validator('presence', {
      presence: true,
      description: t('Backend Prefix'),
    }),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      description: t('Backend Prefix'),
      message: t('must start with "/"'),
    }),
  ],
});

export default DS.Model.extend(Validations, {
  sortOrder: DS.attr('number'),
  frontendPrefix: DS.attr(),
  backendPrefix: DS.attr(),

  backendPrefixWithDefault: computed('backendPrefix', 'frontendPrefix', function() {
    return this.get('backendPrefix') || this.get('frontendPrefix');
  }),
}).reopenClass({
  validationClass: Validations,
});
