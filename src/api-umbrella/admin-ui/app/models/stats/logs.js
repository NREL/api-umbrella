import $ from 'jquery';
import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import { Promise } from 'rsvp';

let Logs = EmberObject.extend(Evented, {
  hits_over_time: null,
  stats: null,
  facets: null,
  logs: null,
});

Logs.reopenClass({
  urlRoot: '/admin/stats/search.json',

  find(params) {
    return new Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new Logs(data));
      }, function(data) {
        reject(data.responseText);
      });
    }.bind(this));
  },
});

export default Logs;
