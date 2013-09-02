Admin.ApisUrlMatchesController = Admin.ApisSortableController.extend({
  actions: {
    reorderUrlMatches: function(event) {
      this.reorderCollection('url_matches');
    },
  },
});
