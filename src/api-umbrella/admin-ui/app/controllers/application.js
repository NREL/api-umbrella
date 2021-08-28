import Controller from '@ember/controller';
import { action } from '@ember/object';
import { reads } from '@ember/object/computed';
import { inject } from '@ember/service';
import classic from 'ember-classic-decorator';

@classic
export default class ApplicationController extends Controller {
  @inject('session')
  session;

  isLoading = null;

  @reads('session.data.authenticated.admin')
  currentAdmin;

  @action
  logout() {
    // Peform a full POST (non-ajax) to the logout URL so the logout URL can
    // redirect to external sites if necessary (for OpenID Connect
    // RP-Initiated Logouts).
    const form = document.createElement('form');
    form.method = 'post';
    form.action = '/admin/logout';
    form.style.display = 'none';

    const csrfToken = document.createElement('input');
    csrfToken.type = 'hidden';
    csrfToken.name = 'csrf_token';
    csrfToken.value = this.session.data.authenticated.csrf_token;
    form.appendChild(csrfToken);

    const submit = document.createElement('input');
    submit.type = 'submit';
    form.appendChild(submit);

    document.body.appendChild(form);
    form.querySelector('[type="submit"]').click()
  }
}
