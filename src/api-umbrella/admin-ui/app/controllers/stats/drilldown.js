import Base from './base';

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
