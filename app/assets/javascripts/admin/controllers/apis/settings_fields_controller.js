Admin.ApisSettingsFieldsController = Ember.ObjectController.extend({
  requireHttpsOptions: [
    { id: null, name: 'Inherit (default - optional)' },
    { id: false, name: 'Optional - HTTPS is optional' },
    { id: true, name: 'Required - HTTPS is mandatory' },
  ],

  disableApiKeyOptions: [
    { id: null, name: 'Inherit (default - required)' },
    { id: false, name: 'Required - API keys are mandatory' },
    { id: true, name: 'Disabled - API keys are optional' },
  ],

  roleOptions: function() {
    return Admin.ApiUserRole.find();
    // Don't cache this property, so we can rely on refreshing the underlying
    // model to refresh the options.
  }.property().cacheable(false),
});
