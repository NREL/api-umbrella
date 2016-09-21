import Base from './base';
import StatsDrilldown from 'api-umbrella-admin-ui/models/stats/drilldown';

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
    prefix: {
      refreshModel: true,
    },
    beta_analytics: {
      refreshModel: true,
    },
  },

  model(params) {
    if(this.validateParams(params)) {
      return StatsDrilldown.find(params);
    } else {
      return {};
    }
  },
});
