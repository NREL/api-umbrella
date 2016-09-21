import Base from './base';
import StatsMap from 'api-umbrella-admin-ui/models/stats/map';

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
    query: {
      refreshModel: true,
    },
    search: {
      refreshModel: true,
    },
    region: {
      refreshModel: true,
    },
    beta_analytics: {
      refreshModel: true,
    },
  },

  model(params) {
    if(this.validateParams(params)) {
      return StatsMap.find(params);
    } else {
      return {};
    }
  },
});

