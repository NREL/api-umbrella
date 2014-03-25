Admin.ApisIndexController = Ember.ArrayController.extend({
  reorderActive: false,

  actions: {
    toggleReorderApis: function(event) {
      this.set('reorderActive', !this.get('reorderActive'));
    },
  },
});
