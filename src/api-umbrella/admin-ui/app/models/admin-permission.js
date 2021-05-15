import classic from 'ember-classic-decorator';
import Model, { attr } from '@ember-data/model';

// eslint-disable-next-line ember/no-classic-classes
@classic
class AdminPermission extends Model {
  @attr()
  name;
}

AdminPermission.reopenClass({
  urlRoot: '/api-umbrella/v1/admin_permissions',
  singlePayloadKey: 'admin_permission',
  arrayPayloadKey: 'admin_permissions',
});

export default AdminPermission;
