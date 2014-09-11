Admin.ApisUrlMatchesController = Admin.ApisSortableController.extend({
  actions: {
    reorderUrlMatches: function() {
      this.reorderCollection('url_matches');
    },
  },
});
