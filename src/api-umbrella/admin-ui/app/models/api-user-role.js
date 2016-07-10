import Model from 'ember-data/model';

export default Model.extend({
}).reopenClass({
  urlRoot: '/api-umbrella/v1/user_roles',
  arrayPayloadKey: 'user_roles',
});
