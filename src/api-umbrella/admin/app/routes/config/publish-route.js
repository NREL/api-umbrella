Admin.ConfigPublishRoute = Ember.Route.extend({
  model: function() {
    return ic.ajax.request('/api-umbrella/v1/config/pending_changes');
  },

  setupController: function(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-config').addClass('active');
  },

  actions: {
    publish: function() {
      var form = $('#publish_form');

      var button = $('#publish_button');
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
        var message = '<h3>Error</h3>';
        try {
          var errors = response.responseJSON.errors;
          for(var prop in errors) {
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
