Admin.ApisUrlMatchFormController = Ember.ObjectController.extend({
  needs: ['modal'],

  title: "Add Matching URL Prefix",

  edit: function(apiModel, urlMatch) {
    this.apiModel = apiModel;

    if(!urlMatch) {
      urlMatch = this.apiModel.get('urlMatches').create();
    }

    this.set('model', urlMatch);
  },

  actions: {
    save: function() {
      this.send('closeModal');
    },

    cancel: function() {
      if(this.get('model').isNew) {
        this.apiModel.get('urlMatches').removeObject(this.get('model'));
      } else {
        this.get('model').revert();
      }

      this.send('closeModal');
    },
  },

  exampleSuffix: 'example.json?param=value',

  exampleIncomingUrl: function() {
    return this.apiModel.get('exampleIncomingUrlRoot') + this.get('frontendPrefix') + this.get('exampleSuffix');
  }.property('frontendPrefix'),

  exampleOutgoingUrl: function() {
    return this.apiModel.get('exampleOutgoingUrlRoot') + this.get('backendPrefixWithDefault') + this.get('exampleSuffix');
  }.property('backendPrefix', 'frontendPrefix'),
});
