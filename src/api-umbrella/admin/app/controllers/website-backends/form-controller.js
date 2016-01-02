Admin.WebsiteBackendsFormController = Ember.ObjectController.extend(Admin.Save, {
  backendProtocolOptions: [
    { id: 'http', name: 'http' },
    { id: 'https', name: 'https' },
  ],

  changeDefaultPort: function() {
    var protocol = this.get('model.backendProtocol');
    var port = parseInt(this.get('model.serverPort'), 10);
    if(protocol === 'https') {
      if(!port || port === 80) {
        this.set('model.serverPort', 443);
      }
    } else {
      if(!port || port === 443) {
        this.set('model.serverPort', 80);
      }
    }
  }.observes('model.backendProtocol'),

  actions: {
    submit: function() {
      this.save({
        transitionToRoute: 'website_backends',
        message: 'Successfully saved the "' + _.escape(this.get('model.frontendHost')) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
      });
    },

    delete: function() {
      bootbox.confirm('Are you sure you want to delete this website backend?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('website_backends');
        }
      }, this));
    },
  },
});

Admin.WebsiteBackendsEditController = Admin.WebsiteBackendsFormController.extend();
Admin.WebsiteBackendsNewController = Admin.WebsiteBackendsFormController.extend();
