import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class UsersLegacyRoute extends Base {
  redirect(params) {
    this.transitionTo('/stats/users?' + params.legacyParams);
  }
}
