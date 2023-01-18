import Base from './base';

export default class UsersLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/users?' + params.legacyParams);
  }
}
