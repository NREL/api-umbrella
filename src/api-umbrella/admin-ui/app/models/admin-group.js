import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  name: validator('presence', true),
});

export default Model.extend(Validations, {
  name: attr(),
  apiScopeIds: attr({ defaultValue() { return [] } }),
  permissionIds: attr({ defaultValue() { return [] } }),
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
