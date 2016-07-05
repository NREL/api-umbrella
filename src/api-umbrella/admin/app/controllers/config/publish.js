import Ember from 'ember';

export default Ember.Controller.extend({
  hasChanges: function() {
    let newApis = this.get('model.config.apis.new');
    let modifiedApis = this.get('model.config.apis.modified');
    let deletedApis = this.get('model.config.apis.deleted');
    let newWebsiteBackends = this.get('model.config.website_backends.new');
    let modifiedWebsiteBackends = this.get('model.config.website_backends.modified');
    let deletedWebsiteBackends = this.get('model.config.website_backends.deleted');

    if(newApis.length > 0 || modifiedApis.length > 0 || deletedApis.length > 0 || newWebsiteBackends.length > 0 || modifiedWebsiteBackends.length > 0 || deletedWebsiteBackends.length > 0) {
      return true;
    } else {
      return false;
    }
  }.property('model.config.apis.new.@each', 'model.config.apis.modified.@each', 'model.config.apis.deleted.@each', 'model.config.website_backends.new.@each', 'model.config.website_backends.modified.@each', 'model.config.website_backends.deleted.@each'),
});
