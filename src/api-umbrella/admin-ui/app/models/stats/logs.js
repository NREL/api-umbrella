import Ember from 'ember';

let Logs = Ember.Object.extend(Ember.Evented, {
  hits_over_time: null,
  stats: null,
  facets: null,
  logs: null,
});

Logs.reopenClass({
  urlRoot: '/admin/stats/search.json',

  find(params) {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new Logs(data));
      }, function() {
        reject();
      });
    }.bind(this));
  },
});

export default Logs;
