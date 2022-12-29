import Controller from '@ember/controller';

export default class BaseController extends Controller {
  search = '';
  interval = 'day';
  prefix = '0/';
  region = 'world';
  date_range = '30d';
  start_at = '';
  end_at = '';
  query = JSON.stringify({
    condition: 'AND',
    rules: [{
      field: 'gatekeeper_denied_code',
      id: 'gatekeeper_denied_code',
      input: 'select',
      operator: 'is_null',
      type: 'string',
      value: null,
    }],
  });
}
