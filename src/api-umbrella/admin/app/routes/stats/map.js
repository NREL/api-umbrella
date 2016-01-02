import Base from './base';

export default Base.extend({
  init: function() {
    _.defaults(this.defaultQueryParams, {
      region: 'world',
    });
  },

  model: function(params) {
    this._super(params);
    return Admin.StatsMap.find(this.get('query.params'));
  },

  queryChange: function() {
    var newQueryParams = this.get('query.params');
    if(newQueryParams && !_.isEmpty(newQueryParams)) {
      var activeQueryParams = this.get('activeQueryParams');
      if(!_.isEqual(newQueryParams, activeQueryParams)) {
        this.transitionTo('stats.map', $.param(newQueryParams));
      }
    }
  }.observes('query.params.query', 'query.params.search', 'query.params.start_at', 'query.params.end_at', 'query.params.region'),
});

