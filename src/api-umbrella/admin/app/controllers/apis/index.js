import Ember from 'ember';

export default Ember.ArrayController.extend({
  reorderActive: false,

  actions: {
    toggleReorderApis: function() {
      this.set('reorderActive', !this.get('reorderActive'));
    },
  },
});
