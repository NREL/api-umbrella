Admin.StatsLogsController = Admin.StatsBaseController.extend({
  downloadUrl: function() {
    return '/admin/stats/logs.csv?' + $.param(this.get('query.params'));
  }.property('query.params', 'query.params.query', 'query.params.search', 'query.params.interval', 'query.params.start_at', 'query.params.end_at'),
});

Admin.StatsLogsDefaultController = Admin.StatsLogsController.extend({
});
