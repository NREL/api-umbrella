import Base from './base';

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
