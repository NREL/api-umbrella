import Ember from 'ember';
import Base from 'ember-simple-auth/authenticators/base';

export default Base.extend({
  restore(data) {
    return this._validate(data) ? Ember.RSVP.Promise.resolve(data) : Ember.RSVP.Promise.reject();
  },

  authenticate() {
    return new Ember.RSVP.Promise((resolve, reject) => {
      $.ajax({
        url: '/admin/auth',
      }).done((data) => {
        if(this._validate(data)) {
          Ember.run(null, resolve, data);
        } else {
          Ember.run(null, reject, 'unauthenticated');
        }
      }).fail((xhr) => {
        Ember.Logger.error('Unexpected error: ' + xhr.status + ' ' + xhr.statusText + ' (' + xhr.readyState + '): ' + xhr.responseText);
        bootbox.alert('An unexpected server error occurred during authentication');
        Ember.run(null, reject, 'unexpected_error');
      });
    });
  },

  invalidate() {
    return new Ember.RSVP.Promise((resolve, reject) => {
      $.ajax({
        url: '/admin/logout',
        method: 'DELETE',
      }).done(() => {
        Ember.run(null, resolve);
      }).fail((xhr) => {
        Ember.Logger.error('Unexpected error: ' + xhr.status + ' ' + xhr.statusText + ' (' + xhr.readyState + '): ' + xhr.responseText);
        bootbox.alert('An unexpected server error occurred during logout');
        Ember.run(null, reject, 'unexpected_error');
      });
    });
  },

  _validate(data) {
    return (data && data.authenticated === true);
  },
});
