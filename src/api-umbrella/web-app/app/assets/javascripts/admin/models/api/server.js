Admin.ApiServer = Ember.Model.extend(Ember.Validations.Mixin, {
  id: Ember.attr(),
  host: Ember.attr(),
  port: Ember.attr(Number),

  validations: {
    host: {
      presence: true,
      format: {
        with: CommonValidations.host_format,
        message: polyglot.t('errors.messages.invalid_host_format'),
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
});

Admin.ApiServer.primaryKey = 'id';
Admin.ApiServer.camelizeKeys = true;
