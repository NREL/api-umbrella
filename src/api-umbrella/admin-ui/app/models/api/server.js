import Ember from 'ember';
import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { validator, buildValidations } from 'ember-cp-validations';

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

  hostWithPort: Ember.computed('host', 'port', function() {
    return _.compact([this.get('host'), this.get('port')]).join(':');
  }),
}).reopenClass({
  validationClass: Validations,
});
