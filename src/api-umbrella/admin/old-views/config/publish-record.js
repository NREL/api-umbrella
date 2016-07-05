import Ember from 'ember';

export default Ember.View.extend({
  actions: {
    toggleConfigDiff: function(id) {
      $('[data-diff-id=' + id + ']').toggle();
    }
  }
});
