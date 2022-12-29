import Model from '@ember-data/model';

class ApiUserRole extends Model {
  static urlRoot = '/api-umbrella/v1/user_roles';
  static arrayPayloadKey = 'user_roles';
}

export default ApiUserRole;
