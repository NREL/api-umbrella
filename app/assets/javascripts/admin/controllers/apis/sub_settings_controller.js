Admin.ApisSubSettingsController = Admin.ApisSortableController.extend({
  actions: {
    reorderSubSettings: function(event) {
      this.reorderCollection('sub_settings');
    },
  },
});
