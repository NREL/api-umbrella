Admin.ApisEditRoute = Ember.Route.extend({
  model: function(params) {
           console.info("FIND: %o", arguments);
    return Admin.Api.find(params.apiId);
  },

  setupController: function(controller, model) {
                     console.info("SETUP: %o", arguments);
    controller.set('model', model);
    //controller.get('controllers.apis').set('model', model);
  }
});

