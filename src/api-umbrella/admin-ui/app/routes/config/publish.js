import Ember from 'ember';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';
import ConfigPendingChanges from 'api-umbrella-admin-ui/models/config-pending-changes';

export default Ember.Route.extend(AuthenticatedRouteMixin, {
  model() {
    return ConfigPendingChanges.fetch();
  },

  setupController(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-config').addClass('active');
  },
});
