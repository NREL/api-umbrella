Admin.ConfigPublishRecordView = Ember.View.extend({
  actions: {
    toggleConfigDiff: function(id) {
      $('[data-diff-id=' + id + ']').toggle();
    }
  }
});
