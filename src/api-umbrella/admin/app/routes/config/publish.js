import Ember from 'ember';
import AuthenticatedRouteMixin from 'ember-simple-auth/mixins/authenticated-route-mixin';

export default Ember.Route.extend(AuthenticatedRouteMixin, {
  model() {
    return ic.ajax.request('/api-umbrella/v1/config/pending_changes');
  },

  setupController(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-config').addClass('active');
  },

  actions: {
    publish() {
      let form = $('#publish_form');

      let button = $('#publish_button');
      button.button('loading');

      ic.ajax.raw({
        url: '/api-umbrella/v1/config/publish',
        type: 'POST',
        data: form.serialize(),
      }).then(_.bind(function() {
        button.button('reset');
        new PNotify({
          type: 'success',
          title: 'Published',
          text: 'Successfully published the configuration<br>Changes should be live in a few seconds...',
        });

        this.refresh();
      }, this), function(response) {
        let message = '<h3>Error</h3>';
        try {
          let errors = response.responseJSON.errors;
          for(let prop in errors) {
            message += prop + ': ' + errors[prop].join(', ') + '<br>';
          }
        } catch(e) {
          message = 'An unexpected error occurred: ' + response.responseText;
        }

        button.button('reset');
        bootbox.alert(message);
      });
    },
  },
});
