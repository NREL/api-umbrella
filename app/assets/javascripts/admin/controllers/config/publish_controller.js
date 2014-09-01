Admin.ConfigPublishController = Ember.Controller.extend({
  hasChanges: function() {
    var newApis = this.get('model.config.apis.new');
    var modifiedApis = this.get('model.config.apis.modified');
    var deletedApis = this.get('model.config.apis.deleted');
    if(newApis.length > 0 || modifiedApis.length > 0 || deletedApis.length > 0) {
      return true;
    } else {
      return false;
    }
  }.property('model.config.apis.new.@each', 'model.config.apis.modified.@each', 'model.config.apis.deleted.@each'),
});
