import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import { Promise } from 'rsvp';

@classic
class Drilldown extends EmberObject.extend(Evented) {
  static urlRoot = '/api-umbrella/v1/analytics/drilldown.json';

  static find(params) {
    return new Promise((resolve, reject) => {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(Drilldown.create(data));
      }, function(data) {
        reject(data.responseText);
      });
    });
  }

  results = null;
}

export default Drilldown;
