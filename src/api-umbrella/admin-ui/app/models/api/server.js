import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

import compact from 'lodash-es/compact';
import { computed } from '@ember/object';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
  host: [
    validator('presence', {
      presence: true,
      description: t('Host'),
    }),
    validator('format', {
      regex: CommonValidations.host_format,
      description: t('Host'),
      message: t('must be in the format of "example.com"'),
    }),
  ],
  port: [
    validator('presence', {
      presence: true,
      description: t('Port'),
    }),
    validator('number', {
      allowString: true,
      description: t('Port'),
    }),
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
