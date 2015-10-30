Admin.ConfigPublishController = Ember.Controller.extend({
  hasChanges: function() {
    var newApis = this.get('model.config.apis.new');
    var modifiedApis = this.get('model.config.apis.modified');
    var deletedApis = this.get('model.config.apis.deleted');
    var newWebsiteBackends = this.get('model.config.website_backends.new');
    var modifiedWebsiteBackends = this.get('model.config.website_backends.modified');
    var deletedWebsiteBackends = this.get('model.config.website_backends.deleted');

    if(newApis.length > 0 || modifiedApis.length > 0 || deletedApis.length > 0 || newWebsiteBackends.length > 0 || modifiedWebsiteBackends.length > 0 || deletedWebsiteBackends.length > 0) {
      return true;
    } else {
      return false;
    }
  }.property('model.config.apis.new.@each', 'model.config.apis.modified.@each', 'model.config.apis.deleted.@each', 'model.config.website_backends.new.@each', 'model.config.website_backends.modified.@each', 'model.config.website_backends.deleted.@each'),
});
