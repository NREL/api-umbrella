Admin.ApiScopesFormController = Ember.ObjectController.extend(Admin.Save, {
  actions: {
    submit: function() {
      this.save({
        transitionToRoute: 'api_scopes',
        message: 'Successfully saved the API scope "' + _.escape(this.get('model.name')) + '"',
      });
    },
  },
});

Admin.ApiScopesEditController = Admin.ApiScopesFormController.extend();
Admin.ApiScopesNewController = Admin.ApiScopesFormController.extend();
