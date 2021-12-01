import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class LogsController extends Base {
  queryParams = [
    'date_range',
    'start_at',
    'end_at',
    'interval',
    'query',
    'search',
  ];
}
