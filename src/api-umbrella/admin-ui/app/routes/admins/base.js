import Ember from 'ember';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';

export default Ember.Route.extend(AuthenticatedRouteMixin, {
  setupController(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-users').addClass('active');
  },
});
