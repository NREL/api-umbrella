import Base from './base';
import StatsLogs from 'api-umbrella-admin/models/stats/logs';

export default Base.extend({
  model(params) {
    if(this.validateParams(params)) {
      return StatsLogs.find(params);
    } else {
      return {};
    }
  },
});
