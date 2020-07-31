import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

import I18n from 'i18n-js';
import compact from 'lodash-es/compact';
import { computed } from '@ember/object';

const Validations = buildValidations({
  host: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format,
      message: I18n.t('errors.messages.invalid_host_format'),
    }),
  ],
  port: [
    validator('presence', true),
    validator('number', { allowString: true }),
  ],
});

export default Model.extend(Validations, {
  host: attr(),
  port: attr('number'),

  hostWithPort: computed('host', 'port', function() {
    return compact([this.host, this.port]).join(':');
  }),
}).reopenClass({
  validationClass: Validations,
});
