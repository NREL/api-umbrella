import Model, { attr } from '@ember-data/model';

class AdminPermission extends Model {
  static urlRoot = '/api-umbrella/v1/admin_permissions';
  static singlePayloadKey = 'admin_permission';
  static arrayPayloadKey = 'admin_permissions';

  @attr()
  name;
}

export default AdminPermission;
