import Ember from 'ember';

export default Ember.View.extend({
  render: function() {
  },

  didInsertElement: function() {
    $('.modal').modal('hide');
  }
});
