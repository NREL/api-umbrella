import Ember from 'ember';

export default Ember.Object.extend(Ember.Evented, {
  hits_over_time: null,
  stats: null,
  facets: null,
  logs: null,
}).reopenClass({
  find: function(params) {
    var promise = Ember.Deferred.create();

    $.ajax({
      url: '/admin/stats/search.json',
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
