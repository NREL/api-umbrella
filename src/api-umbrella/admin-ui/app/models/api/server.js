import Ember from 'ember';
import DS from 'ember-data';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { validator, buildValidations } from 'ember-cp-validations';

const Validations = buildValidations({
  host: [
    validator('presence', true),
    validator('format', {
      regex: CommonValidations.host_format,
      message: t('must be in the format of "example.com"'),
    }),
  ],
  port: [
    validator('presence', true),
    validator('number', { allowString: true }),
  ],
});

export default DS.Model.extend(Validations, {
  host: DS.attr(),
  port: DS.attr('number'),

  hostWithPort: Ember.computed('host', 'port', function() {
    return _.compact([this.get('host'), this.get('port')]).join(':');
  }),
}).reopenClass({
  validationClass: Validations,
});
