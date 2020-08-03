import Model, { attr } from '@ember-data/model';
// eslint-disable-next-line ember/no-observers
import { computed, observer } from '@ember/object';

import moment from 'moment-timezone';
import uniqueId from 'lodash-es/uniqueId';

export default Model.extend({
  duration: attr('number'),
  limitBy: attr(),
  limit: attr(),
  responseHeaders: attr(),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    let duration = this.duration;
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

  // eslint-disable-next-line ember/no-observers
  durationInUnitsDidChange: observer('durationInUnits', 'durationUnits', function() {
    if(this.durationUnits) {
      let inUnits = parseInt(this.durationInUnits, 10);
      let units = this.durationUnits;
      this.set('duration', moment.duration(inUnits, units).asMilliseconds());
    }
  }),

  uniqueId: computed(function() {
    return uniqueId('rate_limit_');
  }),
});
