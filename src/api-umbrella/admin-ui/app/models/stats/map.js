import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import { Promise } from 'rsvp';

@classic
class Map extends EmberObject.extend(Evented) {
  static urlRoot = '/admin/stats/map.json';

  static find(params) {
    return new Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(Map.create(data));
      }, function(data) {
        reject(data.responseText);
      });
    }.bind(this));
  }

  hits_over_time = null;
  stats = null;
  facets = null;
  logs = null;
}

export default Map;
