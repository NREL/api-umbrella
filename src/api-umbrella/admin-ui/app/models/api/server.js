import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';
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

export default DS.Model.extend(Validations, {
  host: DS.attr(),
  port: DS.attr('number'),

  hostWithPort: computed('host', 'port', function() {
    return _.compact([this.get('host'), this.get('port')]).join(':');
  }),
}).reopenClass({
  validationClass: Validations,
});
