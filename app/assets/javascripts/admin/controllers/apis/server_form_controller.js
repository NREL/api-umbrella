Admin.ApisServerFormController = Ember.ObjectController.extend({
  needs: ['modal'],

  title: "Add Server",

  protocolOptions: [
    { id: "http", name: "http" },
    { id: "https", name: "https" },
  ],

  edit: function(apiModel, server) {
    this.apiModel = apiModel;

    if(!server) {
      server = this.apiModel.get('servers').create();
    }

    this.set('model', server);
  },

  save: function() {
    this.send('closeModal');
  },

  cancel: function() {
    if(this.get('model').isNew) {
      this.apiModel.get('servers').removeObject(this.get('model'));
    } else {
      this.get('model').revert();
    }

    this.send('closeModal');
  },
});
