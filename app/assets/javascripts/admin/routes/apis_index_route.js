Admin.ApisIndexRoute = Ember.Route.extend({
  model: function() {
    return Admin.Api.find();
  },

  setupController: function(controller, model) {
console.info("HELLO SETUP INDEX %o", controller);
console.info("HELLO SETUP INDEX %o", model);
    controller.set('model', model);
  }

});
