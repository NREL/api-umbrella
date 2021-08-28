import Model, { attr } from '@ember-data/model';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import classic from 'ember-classic-decorator';
import { buildValidations, validator } from 'ember-cp-validations';

const Validations = buildValidations({
  name: validator('presence', {
    presence: true,
    description: t('Name'),
  }),
});

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
