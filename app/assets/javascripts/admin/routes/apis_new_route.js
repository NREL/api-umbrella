Admin.ApisNewRoute = Ember.Route.extend({
  model: function() {
    var api = Admin.Api.create({
      frontendHost: "api.data.gov", 
    });

    /*
    var urlMatches = api.get('urlMatches');
    urlMatches.create({
      frontendPrefix: '/nrel',
      api: api,
    });


    var servers = api.get('servers');
    servers.create({
      protocol: 'http',
      host: 'developer.nrel.gov',
      port: 80,
    });
    */

    console.info(api);
    console.info(api.servers);
    console.info(api.get('servers'));
    //console.info(api.get('servers')[0]);
    //console.info(api.get('servers').[0]);

    return api;
  },

  setupController: function(controller, model) {
console.info("HELLO SETUP %o", controller);
console.info("HELLO SETUP %o", model);
    controller.set('model', model);
  }
});

