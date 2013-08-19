Admin.ApisFormController = Ember.ObjectController.extend({
  needs: ['apis_server_form', 'apis_url_match_form'],

  balanceAlgorithmOptions: [
    { id: "least_conn", name: "Least Connections" },
    { id: "round_robin", name: "Round Robin" },
    { id: "ip_hash", name: "Source IP Hash" },
  ],

  submit: function() {
    this.get('model').save();
    console.info("SUBMIT %o", this.get('model'));
  },

  addServer: function() {
    this.get('controllers.apis_server_form').edit(this.get('model'));
    this.send('openModal', "apis/server_form");
  },

  editServer: function(server) {
    this.get('controllers.apis_server_form').edit(this.get('model'), server);
    this.send('openModal', "apis/server_form");
  },

  addUrlMatch: function() {
    this.get('controllers.apis_url_match_form').edit(this.get('model'));
    this.send('openModal', "apis/url_match_form");
  },

  editUrlMatch: function(url_match) {
    this.get('controllers.apis_url_match_form').edit(this.get('model'), url_match);
    this.send('openModal', "apis/url_match_form");
  },

  addRoute: function() {
    this.controllerFor("apis_route_form").edit(this.get('model'));
    this.send('openModal', "apis/route_form");
  },

  editRoute: function(route) {
    this.controllerFor("apis_route_form").edit(this.get('model'), route);
    this.send('openModal', "apis/route_form");
  },
});

Admin.ApisEditController = Admin.ApisFormController.extend();
Admin.ApisNewController = Admin.ApisFormController.extend();
