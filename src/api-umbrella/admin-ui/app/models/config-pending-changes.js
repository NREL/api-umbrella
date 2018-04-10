import $ from 'jquery';
import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import { Promise } from 'rsvp';

let ConfigPendingChanges = EmberObject.extend(Evented, {
  config: null,
});

ConfigPendingChanges.reopenClass({
  urlRoot: '/api-umbrella/v1/config/pending_changes.json',

  fetch(params) {
    return new Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new ConfigPendingChanges(data));
      }, function(data) {
        reject(data.responseText);
      });
    }.bind(this));
  },
});

export default ConfigPendingChanges;
