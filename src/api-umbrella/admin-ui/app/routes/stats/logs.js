import Base from './base';
import StatsLogs from 'api-umbrella-admin-ui/models/stats/logs';

export default Base.extend({
  queryParams: {
    date_range: {
      refreshModel: true,
    },
    start_at: {
      refreshModel: true,
    },
    end_at: {
      refreshModel: true,
    },
    interval: {
      refreshModel: true,
    },
    query: {
      refreshModel: true,
    },
    search: {
      refreshModel: true,
    },
  },

  model() {
    let params = this.get('backendQueryParamValues');
    if(this.validateParams(params)) {
      return StatsLogs.find(params);
    } else {
      return {};
    }
  },
});
