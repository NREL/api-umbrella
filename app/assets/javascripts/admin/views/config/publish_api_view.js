Admin.ConfigPublishApiView = Ember.View.extend({
  actions: {
    toggleConfigDiff: function(apiId) {
      $('[data-diff-id=' + apiId + ']').toggle();
    }
  }
});
