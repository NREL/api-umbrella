import Ember from 'ember';
import { Model, attr } from 'ember-model';

export default Model.extend(Ember.Validations.Mixin, {
  id: attr(),
  name: attr(),
  host: attr(),
  pathPrefix: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),

  validations: {
    name: {
      presence: true,
    },
    host: {
      presence: true,
      format: {
        with: CommonValidations.host_format_with_wildcard,
        message: polyglot.t('errors.messages.invalid_host_format'),
      },
    },
    pathPrefix: {
      presence: true,
      format: {
        with: CommonValidations.url_prefix_format,
        message: polyglot.t('errors.messages.invalid_url_prefix_format'),
      },
    },
  },

  displayName: function() {
    return this.get('name') + ' - ' + this.get('host') + this.get('pathPrefix');
  }.property('name', 'host', 'pathPrefix')
}).reopenClass({
  url: '/api-umbrella/v1/api_scopes',
  rootKey: 'api_scope',
  collectionKey: 'data',
  primaryKey: 'id',
  camelizeKeys: true,
  adapter: Admin.APIUmbrellaRESTAdapter.create(),
});
