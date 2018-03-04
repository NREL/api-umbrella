import { buildValidations, validator } from 'ember-cp-validations';

import DS from 'ember-data';

const Validations = buildValidations({
  name: validator('presence', true),
});

export default DS.Model.extend(Validations, {
  name: DS.attr(),
  apiScopeIds: DS.attr({ defaultValue() { return [] } }),
  permissionIds: DS.attr({ defaultValue() { return [] } }),
  admins: DS.attr(),
  createdAt: DS.attr(),
  updatedAt: DS.attr(),
  creator: DS.attr(),
  updater: DS.attr(),
}).reopenClass({
  urlRoot: '/api-umbrella/v1/admin_groups',
  singlePayloadKey: 'admin_group',
  arrayPayloadKey: 'data',
});
