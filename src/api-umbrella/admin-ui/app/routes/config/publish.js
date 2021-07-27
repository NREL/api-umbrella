import Route from '@ember/routing/route';
import ConfigPendingChanges from 'api-umbrella-admin-ui/models/config-pending-changes';
import classic from 'ember-classic-decorator';
// eslint-disable-next-line ember/no-mixins
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';
import $ from 'jquery';

@classic
export default class PublishRoute extends Route.extend(AuthenticatedRouteMixin) {
  model() {
    return ConfigPendingChanges.fetch();
  }

  setupController(controller, model) {
    controller.set('model', model);

    $('ul.navbar-nav li').removeClass('active');
    $('ul.navbar-nav li.nav-config').addClass('active');
  }
}
