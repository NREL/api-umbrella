import StatsLogs from 'api-umbrella-admin-ui/models/stats/logs';

import Base from './base';

export default class LogsRoute extends Base {
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
    interval: {
      refreshModel: true,
    },
    query: {
      refreshModel: true,
    },
    search: {
      refreshModel: true,
    },
  };

  model() {
    let params = this.backendQueryParamValues;
    if(this.validateParams(params)) {
      return StatsLogs.find(params);
    } else {
      return {};
    }
  }
}
