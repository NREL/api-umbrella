import Base from './base';
import StatsLogs from 'api-umbrella-admin-ui/models/stats/logs';

export default Base.extend({
  queryParams: {
    tz: {
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
    beta_analytics: {
      refreshModel: true,
    },
  },

  model(params) {
    if(this.validateParams(params)) {
      return StatsLogs.find(params);
    } else {
      return {};
    }
  },
});
