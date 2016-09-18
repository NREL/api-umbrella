import Ember from 'ember';
import Base from 'ember-simple-auth/authenticators/base';

export default Base.extend({
  ajax: Ember.inject.service(),

  restore(data) {
    return this._validate(data) ? Ember.RSVP.Promise.resolve(data) : Ember.RSVP.Promise.reject();
  },

  authenticate() {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return this.get('ajax').request('/admin/auth').then(function(data) {
        if(this._validate(data)) {
          Ember.run(null, resolve, data);
        } else {
          Ember.run(null, reject);
        }
      }.bind(this)).catch(function(error) {
        Ember.Logger.error(error);
        bootbox.alert('An unexpected server error occurred during authentication');
        Ember.run(null, reject);
      });
    }.bind(this));
  },

  invalidate() {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      return this.get('ajax').request('/admin/logout', { method: 'DELETE' }).then(function() {
        Ember.run(null, resolve);
      }).catch(function() {
        Ember.run(null, reject);
      });
    }.bind(this));
  },

  _validate(data) {
    return (data && data.authenticated === true);
  },
});
