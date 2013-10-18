Admin.StatsLogsRoute = Admin.StatsBaseRoute.extend({
  init: function() {
    _.defaults(this.defaultQueryParams, {
      interval: 'day',
    });
  },

  model: function(params) {
    this._super(params);
    return Admin.StatsLogs.find(this.get('query.params'));
  },

  queryChange: function() {
    var newQueryParams = this.get('query.params');
    if(newQueryParams && !_.isEmpty(newQueryParams)) {
      var activeQueryParams = this.get('activeQueryParams');
      if(!_.isEqual(newQueryParams, activeQueryParams)) {
        this.transitionTo('stats.logs', $.param(newQueryParams));
      }
    }
  }.observes('query.params.search', 'query.params.interval', 'query.params.start', 'query.params.end'),
});

Admin.StatsLogsDefaultRoute = Admin.StatsLogsRoute.extend({
  renderTemplate: function() {
    this.render('stats/logs', { controller: 'statsLogsDefault' });
  }
});
