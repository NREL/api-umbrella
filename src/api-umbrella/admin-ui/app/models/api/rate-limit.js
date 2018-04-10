import DS from 'ember-data';
import moment from 'npm:moment-timezone';
import { observer } from '@ember/object';

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
        this.setProperties({
          durationInUnits: days,
          durationUnits: 'days',
        });
      } else if(hours % 1 === 0) {
        this.setProperties({
          durationInUnits: hours,
          durationUnits: 'hours',
        });
      } else if(minutes % 1 === 0) {
        this.setProperties({
          durationInUnits: minutes,
          durationUnits: 'minutes',
        });
      } else {
        this.setProperties({
          durationInUnits: seconds,
          durationUnits: 'seconds',
        });
      }
    }
  },

  durationInUnitsDidChange: observer('durationInUnits', 'durationUnits', function() {
    if(this.get('durationUnits')) {
      let inUnits = parseInt(this.get('durationInUnits'), 10);
      let units = this.get('durationUnits');
      this.set('duration', moment.duration(inUnits, units).asMilliseconds());
    }
  }),
});
