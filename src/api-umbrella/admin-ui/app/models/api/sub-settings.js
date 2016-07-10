import Ember from 'ember';
import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { belongsTo } from 'ember-data/relationships';

export default Model.extend({
  sortOrder: attr('number'),
  httpMethod: attr(),
  regex: attr(),

  settings: belongsTo('api/settings', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(!this.get('settings')) {
      this.set('settings', this.get('store').createRecord('api/settings'));
    }
  },
});
