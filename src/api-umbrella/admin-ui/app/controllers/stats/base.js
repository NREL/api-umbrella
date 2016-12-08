import Ember from 'ember';

export default Ember.Controller.extend({
  tz: jstz.determine().name(),
  search: '',
  interval: 'day',
  prefix: '0/',
  region: 'world',
  start_at: moment().subtract(29, 'days').format('YYYY-MM-DD'),
  end_at: moment().format('YYYY-MM-DD'),
  query: JSON.stringify({
    condition: 'AND',
    rules: [{
      field: 'gatekeeper_denied_code',
      id: 'gatekeeper_denied_code',
      input: 'select',
      operator: 'is_null',
      type: 'string',
      value: null,
    }],
  }),
  beta_analytics: false,
});
