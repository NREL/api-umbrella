import Controller from '@ember/controller';
import { inject as service } from '@ember/service';

export default class IndexController extends Controller {
  @service session;

  get currentAdmin() {
    return this.session.data.authenticated.admin;
  }
}
