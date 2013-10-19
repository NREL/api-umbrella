Admin.StatsLogs = Ember.Object.extend(Ember.Evented, {
  interval_hits: null,
  stats: null,
  facets: null,
  logs: null,
});

Admin.StatsLogs.reopenClass({
  find: function(params) {
    var promise = Ember.Deferred.create();

    $.ajax({
      url: "/admin/stats/search.json",
      data: params,
    }).done(function(data) {
      var stats = Admin.StatsLogs.create(data);
      promise.resolve(stats);
    }).fail(function() {
      promise.reject();
    });

    return promise;
  },
});
