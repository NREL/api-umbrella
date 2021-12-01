import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class DrilldownLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/drilldown?' + params.legacyParams);
  }
}
