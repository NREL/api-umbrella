import $ from 'jquery';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';
import Route from '@ember/routing/route';

export default Route.extend(AuthenticatedRouteMixin, {
  setupController(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-users').addClass('active');
  },
});
