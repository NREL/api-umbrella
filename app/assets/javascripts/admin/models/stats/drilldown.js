Admin.StatsDrilldown = Ember.Object.extend(Ember.Evented, {
  results: null,
});

Admin.StatsDrilldown.reopenClass({
  find: function(params) {
    var promise = Ember.Deferred.create();

    $.ajax({
      url: '/api-umbrella/v1/analytics/drilldown.json',
      data: params,
    }).done(function(data) {
      var map = Admin.StatsDrilldown.create(data);
      promise.resolve(map);
    }).fail(function() {
      promise.reject();
    });

    return promise;
  },
});
