import Ember from 'ember';
import UnauthenticatedRouteMixin from 'ember-simple-auth/mixins/unauthenticated-route-mixin';

export default Ember.Route.extend(UnauthenticatedRouteMixin, {
  activate() {
    this.authenticate();
  },

  authenticate() {
    this.get('session').authenticate('authenticator:devise-server-side').catch(() => {
      window.location.href = '/admin/login';
    });
  },
});
