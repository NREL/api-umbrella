import EmberObject from '@ember/object';
import Evented from '@ember/object/evented';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import { Promise } from 'rsvp';

@classic
class ConfigPendingChanges extends EmberObject.extend(Evented) {
  static urlRoot = '/api-umbrella/v1/config/pending_changes.json';

  static fetch(params) {
    return new Promise((resolve, reject) => {
      return $.ajax({
        url: this.urlRoot,
        data: params,
      }).then(function(data) {
        resolve(ConfigPendingChanges.create(data));
      }, function(data) {
        reject(data.responseText);
      });
    });
  }

  config = null;
}

export default ConfigPendingChanges;
