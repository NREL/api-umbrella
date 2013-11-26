Admin.ApiRateLimit = Ember.Model.extend({
  _id: Ember.attr(),
  duration: Ember.attr(Number),
  limitBy: Ember.attr(),
  limit: Ember.attr(),
  responseHeaders: Ember.attr(),

  //durationUnits: Ember.attr(),
  //durationInUnits: Ember.attr(Number),

  init: function() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults: function() {
    var duration = this.get('duration');
    if(duration) {
      var days = duration / 86400000;
      var hours = duration / 3600000;
      var minutes = duration / 60000;
      var seconds = duration / 1000;

      if(days % 1 === 0) {
        this.set('durationInUnits', days);
        this.set('durationUnits', 'days');
      } else if(hours % 1 === 0) {
        this.set('durationInUnits', hours);
        this.set('durationUnits', 'hours');
      } else if(minutes % 1 === 0) {
        this.set('durationInUnits', minutes);
        this.set('durationUnits', 'minutes');
      } else {
        this.set('durationInUnits', seconds);
        this.set('durationUnits', 'seconds');
      }
    }
  },

  durationFromUnits: function() {
    if(this.get('durationInUnits') && this.get('durationUnits')) {
      var inUnits = parseInt(this.get('durationInUnits'));
      var units = this.get('durationUnits');
      return moment.duration(inUnits, units).asMilliseconds();
    } else {
      return this.get('duration');
    }
  }.property('durationInUnits', 'durationUnits'),

  settingsId: function() {
    console.info(this);
    console.info(this.get('parent'));
    console.info(this.get('_parent'));
    return this.get('parent._id');
  }.property(),

  toJSON: function() {
    var json = this._super();
    json.duration = this.get('durationFromUnits');
    return json;
  },
});

Admin.ApiRateLimit.primaryKey = "_id";
Admin.ApiRateLimit.camelizeKeys = true;
