import $ from 'jquery';
// eslint-disable-next-line ember/no-mixins
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';
import Route from '@ember/routing/route';

export default Route.extend(AuthenticatedRouteMixin, {
  setupController(controller, model) {
    controller.set('model', model);

    $('ul.navbar-nav li').removeClass('active');
    $('ul.navbar-nav li.nav-users').addClass('active');
  },
});
