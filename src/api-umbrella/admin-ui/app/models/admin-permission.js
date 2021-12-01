import Model, { attr } from '@ember-data/model';
import classic from 'ember-classic-decorator';

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
