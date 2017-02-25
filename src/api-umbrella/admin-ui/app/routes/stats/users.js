import Base from './base';

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

  model() {
    return {};
  },
});
