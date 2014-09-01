Admin.ConfigPublishController = Ember.Controller.extend({
  hasChanges: function() {
    var newApis = this.get('model.apis.new');
    var modifiedApis = this.get('model.apis.modified');
    var deletedApis = this.get('model.apis.deleted');
    if(newApis.length > 0 || modifiedApis.length > 0 || deletedApis.length > 0) {
      return true;
    } else {
      return false;
    }
  }.property(),
});
