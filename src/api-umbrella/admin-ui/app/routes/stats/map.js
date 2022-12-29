import StatsMap from 'api-umbrella-admin-ui/models/stats/map';

import Base from './base';

export default class MapRoute extends Base {
  queryParams = {
    date_range: {
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
  };

  model() {
    let params = this.backendQueryParamValues;
    if(this.validateParams(params)) {
      return StatsMap.find(params);
    } else {
      return {};
    }
  }
}

