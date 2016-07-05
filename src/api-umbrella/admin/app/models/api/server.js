import Ember from 'ember';
import { Model, attr } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  id: attr(),
  host: attr(),
  port: attr(Number),

  validations: {
    host: {
      presence: true,
      format: {
        with: CommonValidations.host_format,
        message: I18n.t('errors.messages.invalid_host_format'),
      },
    },
    port: {
      presence: true,
      numericality: true,
    },
  },

  hostWithPort: function() {
    return _.compact([this.get('host'), this.get('port')]).join(':');
  }.property('host', 'port'),
}).reopenClass({
  primaryKey: 'id',
  camelizeKeys: true,
});
