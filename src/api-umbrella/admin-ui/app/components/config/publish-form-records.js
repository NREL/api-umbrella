import Ember from 'ember';

export default Ember.Component.extend({
  actions: {
    toggleConfigDiff(id) {
      $('[data-diff-id=' + id + ']').toggle();
    },
  },
});
