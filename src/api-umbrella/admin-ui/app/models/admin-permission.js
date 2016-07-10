import Model from 'ember-data/model';
import attr from 'ember-data/attr';

export default Model.extend({
  name: attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admin_permissions',
  singlePayloadKey: 'admin_permission',
  arrayPayloadKey: 'admin_permissions',
});
