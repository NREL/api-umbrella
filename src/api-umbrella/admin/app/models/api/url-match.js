import Ember from 'ember';
import { Model, attr } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  id: attr(),
  sortOrder: attr(Number),
  frontendPrefix: attr(),
  backendPrefix: attr(),

  validations: {
    frontendPrefix: {
      presence: true,
      format: {
        with: CommonValidations.url_prefix_format,
        message: I18n.t('errors.messages.invalid_url_prefix_format'),
      },
    },
    backendPrefix: {
      presence: true,
      format: {
        with: CommonValidations.url_prefix_format,
        message: I18n.t('errors.messages.invalid_url_prefix_format'),
      },
    },
  },

  backendPrefixWithDefault: function() {
    return this.get('backendPrefix') || this.get('frontendPrefix');
  }.property('backendPrefix', 'frontendPrefix'),
}).reopenClass({
  primaryKey: 'id',
  camelizeKeys: true,
});
