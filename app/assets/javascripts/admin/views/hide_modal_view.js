Admin.HideModalView = Ember.View.extend({
  render: function() {
  },

  didInsertElement: function() {
    $(".modal").modal("hide");
  }
});
