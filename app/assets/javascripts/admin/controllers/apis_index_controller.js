Admin.ApisIndexController = Ember.ArrayController.extend({
  actions: {
    delete: function(record) {
      bootbox.confirm('Are you sure you want to delete this API backend?', function(result) {
        if(result) {
          record.deleteRecord();
        }
      });
    },
  },
});
