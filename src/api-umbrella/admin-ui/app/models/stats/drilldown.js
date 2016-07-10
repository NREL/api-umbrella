import Ember from 'ember';

export default Ember.Object.extend(Ember.Evented, {
  results: null,
}).reopenClass({
  find(params) {
    let promise = Ember.Deferred.create();

    $.ajax({
      url: '/api-umbrella/v1/analytics/drilldown.json',
      data: params,
    }).done(function(data) {
      let map = Admin.StatsDrilldown.create(data);
      promise.resolve(map);
    }).fail(function() {
      promise.reject();
    });

    return promise;
  },
});
