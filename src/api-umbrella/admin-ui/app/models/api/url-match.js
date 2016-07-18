import Ember from 'ember';
import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { validator, buildValidations } from 'ember-cp-validations';

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

  backendPrefixWithDefault: Ember.computed('backendPrefix', 'frontendPrefix', function() {
    return this.get('backendPrefix') || this.get('frontendPrefix');
  }),
}).reopenClass({
  validationClass: Validations,
});
