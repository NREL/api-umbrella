import Route from '@ember/routing/route';
import config from '../config/environment';
import { inject } from '@ember/service';

export default Route.extend({
  session: inject('session'),

  activate() {
    // After the server-side logout has completed, this /after-logout route can
    // be used to clear the client-side session.
    this.session.invalidate();

    // Redirect back to the root URL, which should redirect back to the login
    // page.
    window.location.replace(config.rootURL);
  },
});
