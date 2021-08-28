import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class LogsLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/logs?' + params.legacyParams);
  }
}
