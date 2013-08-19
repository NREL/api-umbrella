Model = Ember.Object.extend();
Admin.ApisRouteFormController = Ember.ObjectController.extend({
  needs: ['modal'],

  title: "Add Route",

  matcherOptions: [
    { id: "prefix", name: "Prefix" },
    { id: "pattern", name: "Route Pattern" },
  ],

  httpMethodOptions: [
    { id: "any", name: "Any" },
    { id: "GET", name: "GET" },
    { id: "POST", name: "POST" },
    { id: "PUT", name: "PUT" },
    { id: "DELETE", name: "DELETE" },
    { id: "HEAD", name: "HEAD" },
    { id: "TRACE", name: "TRACE" },
    { id: "OPTIONS", name: "OPTIONS" },
    { id: "CONNECT", name: "CONNECT" },
    { id: "PATCH", name: "PATCH" },
  ],

  edit: function(apiModel, route) {
    this.apiModel = apiModel;

    if(!route) {
      route = this.apiModel.get('routes').create();
    }

    this.set('model', route);
  },

  save: function() {
    this.send('closeModal');
  },

  cancel: function() {
    if(this.get('model').isNew) {
      this.apiModel.get('routes').removeObject(this.get('model'));
    } else {
      this.get('model').revert();
    }

    this.send('closeModal');
  },
});
