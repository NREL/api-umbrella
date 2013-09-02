Admin.ApisIndexRoute = Ember.Route.extend({
  model: function() {
    return Admin.Api.find();
  },

  setupController: function(controller, model) {
    controller.set('model', model);
  },
});
