Admin.ApiUser = Ember.Model.extend({
  id: Ember.attr(),
  apiKey: Ember.attr(),
  apiKeyHidesAt: Ember.attr(),
  apiKeyPreview: Ember.attr(),
  firstName: Ember.attr(),
  lastName: Ember.attr(),
  email: Ember.attr(),
  website: Ember.attr(),
  useDescription: Ember.attr(),
  throttleByIp: Ember.attr(),
  rolesString: Ember.attr(),
  enabled: Ember.attr(),
  createdAt: Ember.attr(),
  updatedAt: Ember.attr(),

  settings: Ember.belongsTo('Admin.ApiSettings', { key: 'settings', embedded: true }),

  init: function() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults: function() {
    if(this.get('throttleByIp') === undefined) {
      this.set('throttleByIp', true);
    }

    if(this.get('enabled') === undefined) {
      this.set('enabled', true);
    }

    if(!this.get('settings')) {
      this.set('settings', Admin.ApiSettings.create());
    }
  },
})

Admin.ApiUser.url = "/admin/api_users";
Admin.ApiUser.rootKey = "api_user";
Admin.ApiUser.collectionKey = "api_users";
Admin.ApiUser.primaryKey = "id";
Admin.ApiUser.camelizeKeys = true;
Admin.ApiUser.adapter = Ember.RESTAdapter.create();
