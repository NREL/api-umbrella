import Ember from 'ember';
import DS from 'ember-data';

export default DS.Model.extend({
  duration: DS.attr('number'),
  limitBy: DS.attr(),
  limit: DS.attr(),
  responseHeaders: DS.attr(),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    let duration = this.get('duration');
    if(duration) {
      let days = duration / 86400000;
      let hours = duration / 3600000;
      let minutes = duration / 60000;
      let seconds = duration / 1000;

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

  durationFromUnits: Ember.computed('durationInUnits', 'durationUnits', function() {
    if(this.get('durationInUnits') && this.get('durationUnits')) {
      let inUnits = parseInt(this.get('durationInUnits'), 10);
      let units = this.get('durationUnits');
      return moment.duration(inUnits, units).asMilliseconds();
    } else {
      return this.get('duration');
    }
  }),

  settingsId: function() {
    return this.get('parent.id');
  }.property(),

  toJSON() {
    let json = this._super();
    json.duration = this.get('durationFromUnits');
    return json;
  },
});
