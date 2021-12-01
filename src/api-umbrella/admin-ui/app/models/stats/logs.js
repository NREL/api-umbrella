import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import { Promise } from 'rsvp';

@classic
class Logs extends EmberObject.extend(Evented) {
  hits_over_time = null;
  stats = null;
  facets = null;
  logs = null;
}

Logs.reopenClass({
  urlRoot: '/admin/stats/search.json',

  find(params) {
    return new Promise(function(resolve, reject) {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(Logs.create(data));
      }, function(data) {
        reject(data.responseText);
      });
    }.bind(this));
  },
});

export default Logs;
