import Model, { attr } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  name: validator('presence', {
    presence: true,
    description: t('Name'),
  }),
});

class AdminGroup extends Model.extend(Validations) {
  static urlRoot = '/api-umbrella/v1/admin_groups';
  static singlePayloadKey = 'admin_group';
  static arrayPayloadKey = 'data';

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

export default AdminGroup;
