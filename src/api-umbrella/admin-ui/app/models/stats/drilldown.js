import $ from 'jquery';
import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import { Promise } from 'rsvp';

let Drilldown = EmberObject.extend(Evented, {
  results: null,
});

Drilldown.reopenClass({
  urlRoot: '/api-umbrella/v1/analytics/drilldown.json',

  find(params) {
    return new Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(new Drilldown(data));
      }, function(data) {
        reject(data.responseText);
      });
    }.bind(this));
  },
});

export default Drilldown;
