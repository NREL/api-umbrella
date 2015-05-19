Admin.AdminsIndexController = Ember.ObjectController.extend({
  queryParams: null,

  downloadUrl: function() {
    return '/api-umbrella/v1/admins.csv?' + $.param(this.get('queryParams')) + '&api_key=' + webAdminAjaxApiKey;
  }.property('queryParams'),

  actions: {
    paramsChange: function(newParams) {
      // Remove paging
      delete newParams.start;
      delete newParams.length;
      this.set('queryParams', newParams);
    }
  }
});
