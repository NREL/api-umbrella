Admin.ApisRewritesController = Admin.ApisSortableController.extend({
  actions: {
    reorderRewrites: function() {
      this.reorderCollection('rewrites');
    },
  },
});
