import ConfigPendingChanges from 'api-umbrella-admin-ui/models/config-pending-changes';
import AuthenticatedRoute from 'api-umbrella-admin-ui/routes/authenticated-route';
import $ from 'jquery';

export default class PublishRoute extends AuthenticatedRoute {
  model() {
    return ConfigPendingChanges.fetch();
  }

  setupController(controller, model) {
    controller.set('model', model);

    $('ul.navbar-nav li').removeClass('active');
    $('ul.navbar-nav li.nav-config').addClass('active');
  }
}
