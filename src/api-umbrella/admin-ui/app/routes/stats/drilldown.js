import Base from './base';
import StatsDrilldown from 'api-umbrella-admin-ui/models/stats/drilldown';

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
    prefix: {
      refreshModel: true,
    },
  },

  model() {
    let params = this.get('backendQueryParamValues');
    if(this.validateParams(params)) {
      return StatsDrilldown.find(params);
    } else {
      return {};
    }
  },
});
