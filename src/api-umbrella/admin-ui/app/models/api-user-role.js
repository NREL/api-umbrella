import classic from 'ember-classic-decorator';
import Model from '@ember-data/model';

// eslint-disable-next-line ember/no-classic-classes
@classic
class ApiUserRole extends Model {}

ApiUserRole.reopenClass({
  urlRoot: '/api-umbrella/v1/user_roles',
  arrayPayloadKey: 'user_roles',
});

export default ApiUserRole;
