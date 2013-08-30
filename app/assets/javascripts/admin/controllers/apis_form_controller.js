Admin.ApisFormController = Ember.ObjectController.extend({
  needs: ['apis_server_form', 'apis_url_match_form'],

  backendProtocolOptions: [
    { id: "http", name: "http" },
    { id: "https", name: "https" },
  ],

  balanceAlgorithmOptions: [
    { id: "least_conn", name: "Least Connections" },
    { id: "round_robin", name: "Round Robin" },
    { id: "ip_hash", name: "Source IP Hash" },
  ],

  actions: {
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

    addRewrite: function() {
      this.controllerFor("apis_rewrite_form").edit(this.get('model'));
      this.send('openModal', "apis/rewrite_form");
    },

    editRewrite: function(rewrite) {
      this.controllerFor("apis_rewrite_form").edit(this.get('model'), rewrite);
      this.send('openModal', "apis/rewrite_form");
    },
  },
});

Admin.ApisEditController = Admin.ApisFormController.extend();
Admin.ApisNewController = Admin.ApisFormController.extend();
