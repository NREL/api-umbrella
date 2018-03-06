import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';

const Validations = buildValidations({
  httpMethod: [
    validator('presence', true),
  ],
  regex: [
    validator('presence', true),
  ],
});

export default DS.Model.extend(Validations, {
  sortOrder: DS.attr('number'),
  httpMethod: DS.attr(),
  regex: DS.attr(),

  settings: DS.belongsTo('api/settings', { async: false }),

  ready() {
    this.setDefaults();
    this._super();
  },

  setDefaults() {
    if(!this.get('settings')) {
      this.set('settings', this.get('store').createRecord('api/settings'));
    }
  },
}).reopenClass({
  validationClass: Validations,
});
