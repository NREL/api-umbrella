import { Model, attr, belongsTo } from 'ember-model';

export default Model.extend({
  id: attr(),
  sortOrder: attr(Number),
  httpMethod: attr(),
  regex: attr(),

  settings: belongsTo('Admin.ApiSettings', { key: 'settings', embedded: true }),

  init() {
    this._super();

    // Set defaults for new records.
    this.setDefaults();

    // For existing records, we need to set the defaults after loading.
    this.on('didLoad', this, this.setDefaults);
  },

  setDefaults() {
    if(!this.get('settings')) {
      this.set('settings', Admin.ApiSettings.create());
    }
  },
}).reopenClass({
  primaryKey: 'id',
  camelizeKeys: true,
});
