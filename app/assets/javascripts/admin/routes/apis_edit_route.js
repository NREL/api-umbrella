Admin.ApisEditRoute = Ember.Route.extend({
  model: function(params) {
    return Admin.Api.find(params.apiId);
  },

  setupController: function(controller, model) {
    controller.set('model', model);
  }
});

