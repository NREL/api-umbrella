import { computed } from '@ember/object';
import Model, { attr } from '@ember-data/model';
import { observes } from '@ember-decorators/object';
import classic from 'ember-classic-decorator';
import uniqueId from 'lodash-es/uniqueId';
import moment from 'moment-timezone';

@classic
export default class RateLimit extends Model {
  @attr('number')
  duration;

  @attr()
  limitBy;

  @attr()
  limit;

  @attr()
  responseHeaders;

  init() {
    super.init(...arguments);

    this.setDefaults();
  }

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
  }

  // eslint-disable-next-line ember/no-observers
  @observes('durationInUnits', 'durationUnits')
  durationInUnitsDidChange() {
    if(this.durationUnits) {
      let inUnits = parseInt(this.durationInUnits, 10);
      let units = this.durationUnits;
      this.set('duration', moment.duration(inUnits, units).asMilliseconds());
    }
  }

  @computed
  get uniqueId() {
    return uniqueId('rate_limit_');
  }
}
