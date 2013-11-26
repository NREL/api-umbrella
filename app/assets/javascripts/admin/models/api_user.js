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
  termsAndConditions: Ember.attr(),
  throttleByIp: Ember.attr(),
  rolesString: Ember.attr(),
  enabled: Ember.attr(),
  createdAt: Ember.attr(),
  updatedAt: Ember.attr(),
  creator: Ember.attr(),
  updater: Ember.attr(),

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

  toJSON: function() {
    var json = this._super();

    // Translate the terms_and_conditions checkbox into the string '1' if true.
    // This is to match how validates_acceptance_of accepts things.
    if(json.api_user && json.api_user.terms_and_conditions === true) {
      json.api_user.terms_and_conditions = '1';
    }

    return json;
  },
})

Admin.ApiUser.url = "/admin/api_users";
Admin.ApiUser.rootKey = "api_user";
Admin.ApiUser.collectionKey = "api_users";
Admin.ApiUser.primaryKey = "id";
Admin.ApiUser.camelizeKeys = true;
Admin.ApiUser.adapter = Ember.RESTAdapter.create();
