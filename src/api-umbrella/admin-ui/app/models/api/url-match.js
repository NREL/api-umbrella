import Ember from 'ember';
import DS from 'ember-data';
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

export default DS.Model.extend(Validations, {
  sortOrder: DS.attr('number'),
  frontendPrefix: DS.attr(),
  backendPrefix: DS.attr(),

  backendPrefixWithDefault: Ember.computed('backendPrefix', 'frontendPrefix', function() {
    return this.get('backendPrefix') || this.get('frontendPrefix');
  }),
}).reopenClass({
  validationClass: Validations,
});
