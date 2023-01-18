import Base from './base';

export default class MapController extends Base {
  queryParams = [
    'start_at',
    'end_at',
    'query',
    'search',
    'region',
  ];
}
