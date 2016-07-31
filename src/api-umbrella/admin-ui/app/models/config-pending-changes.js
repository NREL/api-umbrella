import Ember from 'ember';

let ConfigPendingChanges = Ember.Object.extend(Ember.Evented, {
  config: null,
});

ConfigPendingChanges.reopenClass({
  urlRoot: '/api-umbrella/v1/config/pending_changes.json',

  fetch(params) {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params
      }).then(function(data) {
        resolve(new ConfigPendingChanges(data));
      }, function() {
        reject();
      });
    }.bind(this));
  },
});

export default ConfigPendingChanges;
