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
      }.bind(this), function(xhr) {
        Ember.run(null, reject);
      });
    }.bind(this));
  },

  invalidate(data) {
  },

  _validate(data) {
    return (data && data.authenticated === true);
  },
});
