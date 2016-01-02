Admin.ApisFormController = Ember.ObjectController.extend(Admin.Save, {
  needs: [
    'apis_server_form',
    'apis_url_match_form',
    'apis_sub_settings_form',
    'apis_rewrite_form',
  ],

  backendProtocolOptions: [
    { id: 'http', name: 'http' },
    { id: 'https', name: 'https' },
  ],

  balanceAlgorithmOptions: [
    { id: 'least_conn', name: 'Least Connections' },
    { id: 'round_robin', name: 'Round Robin' },
    { id: 'ip_hash', name: 'Source IP Hash' },
  ],

  actions: {
    submit: function() {
      this.save({
        transitionToRoute: 'apis',
        message: 'Successfully saved the "' + _.escape(this.get('model.name')) + '" API backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
      });
    },

    delete: function() {
      bootbox.confirm('Are you sure you want to delete this API backend?', _.bind(function(result) {
        if(result) {
          this.get('model').deleteRecord();
          this.transitionToRoute('apis');
        }
      }, this));
    },

    addServer: function() {
      this.get('controllers.apis_server_form').add(this.get('model'), 'servers');

      // For new servers, intelligently pick the default port based on the
      // backend protocol selected.
      if(this.get('model.backendProtocol') === 'https') {
        this.set('controllers.apis_server_form.model.port', 443);
      } else {
        this.set('controllers.apis_server_form.model.port', 80);
      }

      // After the first server is added, fill out a default value for the
      // "Backend Host" field based on the server's host (because in most
      // non-load balancing situations they will match).
      this.get('controllers.apis_server_form').on('closeOk', _.bind(function() {
        var server = this.get('model.servers.firstObject');
        if(!this.get('model.backendHost') && server) {
          this.set('model.backendHost', server.get('host'));
        }
      }, this));

      this.send('openModal', 'apis/server_form');
    },

    editServer: function(server) {
      this.get('controllers.apis_server_form').edit(this.get('model'), 'servers', server);
      this.send('openModal', 'apis/server_form');
    },

    deleteServer: function(server) {
      this.deleteChildRecord('servers', server, 'Are you sure you want to remove this server?');
    },

    addUrlMatch: function() {
      this.get('controllers.apis_url_match_form').add(this.get('model'), 'urlMatches');
      this.send('openModal', 'apis/url_match_form');
    },

    editUrlMatch: function(urlMatch) {
      this.get('controllers.apis_url_match_form').edit(this.get('model'), 'urlMatches', urlMatch);
      this.send('openModal', 'apis/url_match_form');
    },

    deleteUrlMatch: function(urlMatch) {
      this.deleteChildRecord('urlMatches', urlMatch, 'Are you sure you want to remove this URL prefix?');
    },

    addSubSettings: function() {
      this.get('controllers.apis_sub_settings_form').add(this.get('model'), 'subSettings');
      this.send('openModal', 'apis/sub_settings_form');
    },

    editSubSettings: function(subSettings) {
      this.get('controllers.apis_sub_settings_form').edit(this.get('model'), 'subSettings', subSettings);
      this.send('openModal', 'apis/sub_settings_form');
    },

    deleteSubSettings: function(subSettings) {
      this.deleteChildRecord('subSettings', subSettings, 'Are you sure you want to remove this URL setting?');
    },

    addRewrite: function() {
      this.get('controllers.apis_rewrite_form').add(this.get('model'), 'rewrites');
      this.send('openModal', 'apis/rewrite_form');
    },

    editRewrite: function(rewrite) {
      this.get('controllers.apis_rewrite_form').edit(this.get('model'), 'rewrites', rewrite);
      this.send('openModal', 'apis/rewrite_form');
    },

    deleteRewrite: function(rewrite) {
      this.deleteChildRecord('rewrites', rewrite, 'Are you sure you want to remove this rewrite?');
    },
  },

  deleteChildRecord: function(collectionName, record, message) {
    var collection = this.get('model').get(collectionName);
    bootbox.confirm(message, function(result) {
      if(result) {
        collection.removeObject(record);
      }
    });
  },
});

Admin.ApisEditController = Admin.ApisFormController.extend();
Admin.ApisNewController = Admin.ApisFormController.extend();
