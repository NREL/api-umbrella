import Base from './base';

export default class LogsLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/logs?' + params.legacyParams);
  }
}
