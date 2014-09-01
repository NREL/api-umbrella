Admin.ConfigPublishRoute = Ember.Route.extend({
  model: function() {
    return ic.ajax.request('/api-umbrella/v1/config/pending');
  },

  setupController: function(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-config').addClass('active');
  },
});
