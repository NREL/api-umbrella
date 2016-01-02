import Ember from 'ember';
import { Model, attr } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  id: attr(),
  frontendHost: attr(),
  backendProtocol: attr(),
  serverHost: attr(),
  serverPort: attr(Number),

  validations: {
    frontendHost: {
      presence: true,
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: polyglot.t('errors.messages.invalid_host_format'),
      },
    },
    backendProtocol: {
      presence: true,
    },
    serverHost: {
      presence: true,
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: polyglot.t('errors.messages.invalid_host_format'),
      },
    },
    serverPort: {
      presence: true,
      numericality: true,
    },
  },
}).reopenClass({
  url: '/api-umbrella/v1/website_backends',
  rootKey: 'website_backend',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
