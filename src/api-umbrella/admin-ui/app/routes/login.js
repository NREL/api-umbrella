import Route from '@ember/routing/route';
import UnauthenticatedRouteMixin from 'ember-simple-auth/mixins/unauthenticated-route-mixin';

export default Route.extend(UnauthenticatedRouteMixin, {
  activate() {
    this.authenticate();
  },

  authenticate() {
    this.get('session').authenticate('authenticator:devise-server-side').catch((error) => {
      if(error !== 'unexpected_error') {
        window.location.href = '/admin/login';
      }
    });
  },
});
