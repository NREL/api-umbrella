import Model, { attr } from '@ember-data/model';
import { observes } from '@ember-decorators/object';
import uniqueId from 'lodash-es/uniqueId';
import moment from 'moment-timezone';
import classic from 'ember-classic-decorator';

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
        this.durationInUnits = days;
        this.durationUnits = 'days';
      } else if(hours % 1 === 0) {
        this.durationInUnits = hours;
        this.durationUnits = 'hours';
      } else if(minutes % 1 === 0) {
        this.durationInUnits = minutes;
        this.durationUnits = 'minutes';
      } else {
        this.durationInUnits = seconds;
        this.durationUnits = 'seconds';
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

  get uniqueId() {
    if(!this.uniqueIdValue) {
      this.uniqueIdValue = uniqueId('rate_limit_');
    }

    return this.uniqueIdValue;
  }
}
