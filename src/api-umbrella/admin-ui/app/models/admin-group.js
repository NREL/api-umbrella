import classic from 'ember-classic-decorator';
import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  name: validator('presence', true),
});

// eslint-disable-next-line ember/no-classic-classes
@classic
class AdminGroup extends Model.extend(Validations) {
  @attr()
  name;

  @attr({ defaultValue() { return [] } })
  apiScopeIds;

  @attr({ defaultValue() { return [] } })
  permissionIds;

  @attr()
  admins;

  @attr()
  createdAt;

  @attr()
  updatedAt;

  @attr()
  creator;

  @attr()
  updater;
}

AdminGroup.reopenClass({
  urlRoot: '/api-umbrella/v1/admin_groups',
  singlePayloadKey: 'admin_group',
  arrayPayloadKey: 'data',
});

export default AdminGroup;
