import Base from './base';

export default class DrilldownLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/drilldown?' + params.legacyParams);
  }
}
