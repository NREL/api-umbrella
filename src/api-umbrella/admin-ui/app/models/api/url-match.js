import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

import I18n from 'i18n-js';
import { computed } from '@ember/object';

const Validations = buildValidations({
  frontendPrefix: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      message: I18n.t('errors.messages.invalid_url_prefix_format'),
    }),
  ],
  backendPrefix: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.url_prefix_format,
      message: I18n.t('errors.messages.invalid_url_prefix_format'),
    }),
  ],
});

export default Model.extend(Validations, {
  sortOrder: attr('number'),
  frontendPrefix: attr(),
  backendPrefix: attr(),

  backendPrefixWithDefault: computed.or('backendPrefix', 'frontendPrefix'),
}).reopenClass({
  validationClass: Validations,
});
