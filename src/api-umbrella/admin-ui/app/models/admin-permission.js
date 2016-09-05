import DS from 'ember-data';

export default DS.Model.extend({
  name: DS.attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admin_permissions',
  singlePayloadKey: 'admin_permission',
  arrayPayloadKey: 'admin_permissions',
});
