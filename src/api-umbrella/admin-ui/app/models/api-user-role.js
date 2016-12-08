import DS from 'ember-data';

export default DS.Model.extend({
}).reopenClass({
  urlRoot: '/api-umbrella/v1/user_roles',
  arrayPayloadKey: 'user_roles',
});
