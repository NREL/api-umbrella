import Ember from 'ember';

let Drilldown = Ember.Object.extend(Ember.Evented, {
  results: null,
});

Drilldown.reopenClass({
  urlRoot: '/api-umbrella/v1/analytics/drilldown.json',

  find(params) {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new Drilldown(data));
      }, function() {
        reject();
      });
    }.bind(this));
  },
});

export default Drilldown;
