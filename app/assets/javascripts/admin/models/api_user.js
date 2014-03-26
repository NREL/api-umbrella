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
  registrationSource: Ember.attr(),
  termsAndConditions: Ember.attr(),
  sendWelcomeEmail: Ember.attr(),
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
      this.set('throttleByIp', false);
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

Admin.ApiUser.url = "/api-umbrella/v1/users";
Admin.ApiUser.rootKey = "user";
Admin.ApiUser.collectionKey = "users";
Admin.ApiUser.primaryKey = "id";
Admin.ApiUser.camelizeKeys = true;
Admin.ApiUser.adapter = Admin.APIUmbrellaRESTAdapter.create();
