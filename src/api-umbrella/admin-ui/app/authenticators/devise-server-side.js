import { run } from '@ember/runloop';
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import Base from 'ember-simple-auth/authenticators/base';
import $ from 'jquery';
import { Promise } from 'rsvp';

@classic
export default class DeviseServerSide extends Base {
  restore() {
    // Perform a full validation against the server-side endpoint to verify the
    // user's authentication on load. We use this, instead of validating the
    // data stored client side, since the user's server-side session may have
    // expired, even if the local client data thinks it's authenticated.
    return this.authenticate();
  }

  authenticate() {
    return new Promise((resolve, reject) => {
      $.ajax({
        url: '/admin/auth',
      }).done((data) => {
        if(this._validate(data)) {
          run(null, resolve, data);
        } else {
          run(null, reject, 'unauthenticated');
        }
      }).fail((xhr) => {
        // eslint-disable-next-line no-console
        console.error('Unexpected error: ' + xhr.status + ' ' + xhr.statusText + ' (' + xhr.readyState + '): ' + xhr.responseText);
        bootbox.alert('An unexpected server error occurred during authentication');
        run(null, reject, 'unexpected_error');
      });
    });
  }

  _validate(data) {
    return (data && data.authenticated === true);
  }
}
