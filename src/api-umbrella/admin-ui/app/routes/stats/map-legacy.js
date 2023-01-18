import Base from './base';

export default class MapLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/map?' + params.legacyParams);
  }
}
