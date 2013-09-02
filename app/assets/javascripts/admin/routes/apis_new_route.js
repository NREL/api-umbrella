Admin.ApisNewRoute = Ember.Route.extend({
  model: function() {
    return Admin.Api.create({
      frontendHost: "api.data.gov", 
    });
  },

  setupController: function(controller, model) {
    controller.set('model', model);
  },
});

