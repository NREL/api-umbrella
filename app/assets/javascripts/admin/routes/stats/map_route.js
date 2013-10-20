Admin.StatsMapRoute = Admin.StatsBaseRoute.extend({
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
  }.observes('query.params.search', 'query.params.start', 'query.params.end', 'query.params.region'),
});

Admin.StatsMapDefaultRoute = Admin.StatsMapRoute.extend({
  renderTemplate: function() {
    this.render('stats/map', { controller: 'statsMapDefault' });
  }
});
