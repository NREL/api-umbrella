import Base from './base';

export default Base.extend({
  model(params) {
    this._super(params);
    return {};
  },

  queryChange: function() {
    let newQueryParams = this.get('query.params');
    if(newQueryParams && !_.isEmpty(newQueryParams)) {
      let activeQueryParams = this.get('activeQueryParams');
      if(!_.isEqual(newQueryParams, activeQueryParams)) {
        this.transitionTo('stats.users', $.param(newQueryParams));
      }
    }
  }.observes('query.params.query', 'query.params.search', 'query.params.start_at', 'query.params.end_at', 'query.params.beta_analytics'),
});
