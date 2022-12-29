import Route from '@ember/routing/route';
import { inject } from '@ember/service';

import config from '../config/environment';

export default class AfterLogout extends Route {
  @inject session;

  activate() {
    // After the server-side logout has completed, this /after-logout route can
    // be used to clear the client-side session.
    this.session.invalidate();

    // Redirect back to the root URL, which should redirect back to the login
    // page.
    window.location.replace(config.rootURL);
  }
}
