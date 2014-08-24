Admin.StatsLogsController = Admin.StatsBaseController.extend({
  downloadUrl: function() {
    return '/admin/stats/logs.csv?' + $.param(this.get('query.params'));
  }.property('query.params', 'query.params.search', 'query.params.interval', 'query.params.start', 'query.params.end'),
});

Admin.StatsLogsDefaultController = Admin.StatsLogsController.extend({
});
