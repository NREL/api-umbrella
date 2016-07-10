import Model from 'ember-data/model';
import attr from 'ember-data/attr';
import { validator, buildValidations } from 'ember-cp-validations';

const Validations = buildValidations({
  name: validator('presence', true),
});

export default Model.extend(Validations, {
  name: attr(),
  apiScopeIds: attr(),
  permissionIds: attr(),
  admins: attr(),
  createdAt: attr(),
  updatedAt: attr(),
  creator: attr(),
  updater: attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admin_groups',
  singlePayloadKey: 'admin_group',
  arrayPayloadKey: 'data',
});
