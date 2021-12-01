import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class MapLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/map?' + params.legacyParams);
  }
}
