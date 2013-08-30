Model = Ember.Object.extend();
Admin.ApisRewriteFormController = Ember.ObjectController.extend({
  needs: ['modal'],

  title: "Add Rewrite",

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

  edit: function(apiModel, rewrite) {
    this.apiModel = apiModel;

    if(!rewrite) {
      rewrite = this.apiModel.get('rewrites').create();
    }

    this.set('model', rewrite);
  },

  actions: {
    save: function() {
      this.send('closeModal');
    },

    cancel: function() {
      if(this.get('model').isNew) {
        this.apiModel.get('rewrites').removeObject(this.get('model'));
      } else {
        this.get('model').revert();
      }

      this.send('closeModal');
    },
  },
});
