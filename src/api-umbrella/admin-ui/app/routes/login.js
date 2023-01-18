import Route from '@ember/routing/route';
import { inject as service } from '@ember/service';

export default class LoginRoute extends Route {
  @service session;

  beforeModel() {
    this.session.prohibitAuthentication('index');
  }

  activate() {
    this.authenticate();
  }

  authenticate() {
    this.session.authenticate('authenticator:devise-server-side').catch((error) => {
      if(error !== 'unexpected_error') {
        window.location.href = '/admin/login';
      }
    });
  }
}
