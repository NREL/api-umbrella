import Model, { attr } from '@ember-data/model';

export default Model.extend({
  name: attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admin_permissions',
  singlePayloadKey: 'admin_permission',
  arrayPayloadKey: 'admin_permissions',
});
