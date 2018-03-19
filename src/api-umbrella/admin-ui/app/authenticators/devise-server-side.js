import $ from 'jquery';
import Base from 'ember-simple-auth/authenticators/base';
import { Promise } from 'rsvp';
import { run } from '@ember/runloop';

export default Base.extend({
  restore() {
    // Perform a full validation against the server-side endpoint to verify the
    // user's authentication on load. We use this, instead of validating the
    // data stored client side, since the user's server-side session may have
    // expired, even if the local client data thinks it's authenticated.
    return this.authenticate();
  },

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
  },

  invalidate() {
    return new Promise((resolve, reject) => {
      $.ajax({
        url: '/admin/logout',
        method: 'DELETE',
      }).done(() => {
        run(null, resolve);
      }).fail((xhr) => {
        // eslint-disable-next-line no-console
        console.error('Unexpected error: ' + xhr.status + ' ' + xhr.statusText + ' (' + xhr.readyState + '): ' + xhr.responseText);
        bootbox.alert('An unexpected server error occurred during logout');
        run(null, reject, 'unexpected_error');
      });
    });
  },

  _validate(data) {
    return (data && data.authenticated === true);
  },
});
