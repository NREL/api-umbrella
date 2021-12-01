import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class DrilldownController extends Base {
  queryParams = [
    'start_at',
    'end_at',
    'interval',
    'query',
    'search',
    'prefix',
  ];
}
