import Ember from 'ember';
import ApplicationRouteMixin from 'ember-simple-auth/mixins/application-route-mixin';

export default Ember.Route.extend(ApplicationRouteMixin, {
  busy: Ember.inject.service('busy'),

  actions: {
    loading(transition) {
      let busy = this.get('busy');
      busy.show();
      transition.promise.finally(function() {
        busy.hide();
      });
    },

    error() {
      this.get('busy').hide();
    },
  },
});
