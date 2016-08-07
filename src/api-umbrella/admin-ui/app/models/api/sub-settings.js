import DS from 'ember-data';

export default DS.Model.extend({
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
});
