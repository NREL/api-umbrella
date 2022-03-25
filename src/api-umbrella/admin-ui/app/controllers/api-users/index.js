import Controller from '@ember/controller';
import { reads } from '@ember/object/computed';
import { inject } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class IndexController extends Controller {
  @inject('session')
  session;

  @reads('session.data.authenticated.admin')
  currentAdmin;
}
