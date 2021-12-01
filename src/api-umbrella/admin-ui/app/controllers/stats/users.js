import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class UsersController extends Base {
  queryParams = [
    'start_at',
    'end_at',
    'query',
    'search',
  ];
}
