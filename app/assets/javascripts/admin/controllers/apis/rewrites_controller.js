Admin.ApisRewritesController = Admin.ApisSortableController.extend({
  actions: {
    reorderRewrites: function(event) {
      this.reorderCollection('rewrites');
    },
  },
});
