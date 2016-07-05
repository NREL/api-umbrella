import Ember from 'ember';

export default Ember.Object.extend(Ember.Evented, {
  regions: null,
  map_regions: null,
}).reopenClass({
  find(params) {
    let promise = Ember.Deferred.create();

    $.ajax({
      url: '/admin/stats/map.json',
      data: params,
    }).done(function(data) {
      let map = Admin.StatsMap.create(data);
      promise.resolve(map);
    }).fail(function() {
      promise.reject();
    });

    return promise;
  },
});
