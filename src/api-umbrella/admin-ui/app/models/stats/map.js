import $ from 'jquery';
import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import { Promise } from 'rsvp';

let Map = EmberObject.extend(Evented, {
  hits_over_time: null,
  stats: null,
  facets: null,
  logs: null,
});

Map.reopenClass({
  urlRoot: '/admin/stats/map.json',

  find(params) {
    return new Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new Map(data));
      }, function(data) {
        reject(data.responseText);
      });
    }.bind(this));
  },
});

export default Map;
