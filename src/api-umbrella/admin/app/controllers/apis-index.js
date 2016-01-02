import Ember from 'ember';

Admin.ApisIndexController = Ember.ArrayController.extend({
  reorderActive: false,

  actions: {
    toggleReorderApis: function() {
      this.set('reorderActive', !this.get('reorderActive'));
    },
  },
});

export default undefined;
