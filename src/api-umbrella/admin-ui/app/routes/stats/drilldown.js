import StatsDrilldown from 'api-umbrella-admin-ui/models/stats/drilldown';
import classic from 'ember-classic-decorator';

import Base from './base';

@classic
export default class DrilldownRoute extends Base {
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
    prefix: {
      refreshModel: true,
    },
  };

  model() {
    let params = this.backendQueryParamValues;
    if(this.validateParams(params)) {
      return StatsDrilldown.find(params);
    } else {
      return {};
    }
  }
}
