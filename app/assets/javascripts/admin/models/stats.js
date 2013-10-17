Admin.Stats = Ember.Object.extend(Ember.Evented, {
  interval_hits: null,
  totals: null,
  facets: null,
  logs: null,
});

Admin.Stats.reopenClass({
  find: function(params) {
    var promise = Ember.Deferred.create();

    $.ajax({
      url: "/admin/stats/search.json",
      data: params,
    }).done(function(data) {
      var stats = Admin.Stats.create(data);
      promise.resolve(stats);
    }).fail(function() {
      promise.reject();
    });

    return promise;
  },
});
