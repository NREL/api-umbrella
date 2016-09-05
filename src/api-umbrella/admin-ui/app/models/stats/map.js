import Ember from 'ember';

let Map = Ember.Object.extend(Ember.Evented, {
  hits_over_time: null,
  stats: null,
  facets: null,
  logs: null,
});

Map.reopenClass({
  urlRoot: '/admin/stats/map.json',

  find(params) {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new Map(data));
      }, function() {
        reject();
      });
    }.bind(this));
  },
});

export default Map;
