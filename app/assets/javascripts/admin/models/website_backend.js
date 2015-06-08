Admin.WebsiteBackend = Ember.Model.extend(Ember.Validations.Mixin, {
  id: Ember.attr(),
  frontendHost: Ember.attr(),
  backendProtocol: Ember.attr(),
  serverHost: Ember.attr(),
  serverPort: Ember.attr(Number),

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
});

Admin.WebsiteBackend.url = '/api-umbrella/v1/website_backends';
Admin.WebsiteBackend.rootKey = 'website_backend';
Admin.WebsiteBackend.collectionKey = 'data';
Admin.WebsiteBackend.primaryKey = 'id';
Admin.WebsiteBackend.camelizeKeys = true;
Admin.WebsiteBackend.adapter = Admin.APIUmbrellaRESTAdapter.create();
