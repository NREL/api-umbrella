import Model, { attr } from '@ember-data/model';
import { buildValidations, validator } from 'ember-cp-validations';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

const Validations = buildValidations({
  name: validator('presence', {
    presence: true,
    description: t('Name'),
  }),
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
