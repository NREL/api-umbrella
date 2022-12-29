import Base from './base';

export default class UsersController extends Base {
  queryParams = [
    'start_at',
    'end_at',
    'query',
    'search',
  ];
}
