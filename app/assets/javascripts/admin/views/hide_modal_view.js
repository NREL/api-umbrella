Admin.HideModalView = Ember.View.extend({
  render: function() {
  },

  didInsertElement: function() {
console.info("HELLO HIDE");
    $(".modal").modal("hide");
  }
});
