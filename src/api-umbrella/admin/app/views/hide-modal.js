import Ember from 'ember';

Admin.HideModalView = Ember.View.extend({
  render: function() {
  },

  didInsertElement: function() {
    $('.modal').modal('hide');
  }
});

export default undefined;
