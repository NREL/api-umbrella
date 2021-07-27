import Model from '@ember-data/model';
import classic from 'ember-classic-decorator';

@classic
class ApiUserRole extends Model {}

ApiUserRole.reopenClass({
  urlRoot: '/api-umbrella/v1/user_roles',
  arrayPayloadKey: 'user_roles',
});

export default ApiUserRole;
