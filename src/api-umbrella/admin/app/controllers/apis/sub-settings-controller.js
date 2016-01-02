Admin.ApisSubSettingsController = Admin.ApisSortableController.extend({
  actions: {
    reorderSubSettings: function() {
      this.reorderCollection('sub_settings');
    },
  },
});

export default undefined;
