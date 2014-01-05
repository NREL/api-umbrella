Admin.StatsLogsController = Admin.StatsBaseController.extend({
  downloadUrl: function() {
    return '/admin/stats/logs.csv?' + $.param(this.get('query.params'));
  }.property('query.params'),
});

Admin.StatsLogsDefaultController = Admin.StatsLogsController.extend({
});
