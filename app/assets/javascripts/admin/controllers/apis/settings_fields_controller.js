Admin.ApisSettingsFieldsController = Ember.ObjectController.extend({
  requireHttpsOptions: [
    { id: null, name: "Inherit (default - optional)" },
    { id: false, name: "Optional - HTTPS is optional" },
    { id: true, name: "Required - HTTPS is mandatory" },
  ],

  disableApiKeyOptions: [
    { id: null, name: "Inherit (default - required)" },
    { id: false, name: "Required - API keys are mandatory" },
    { id: true, name: "Disabled - API keys are optional" },
  ],

  // FIXME: Don't use a global variable for getting the list of roles.
  roleOptions: apiUserExistingRoles,
});
