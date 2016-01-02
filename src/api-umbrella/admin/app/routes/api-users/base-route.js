Admin.ApiUsersBaseRoute = Ember.Route.extend({
  setupController: function(controller, model) {
    controller.set('model', model);

    $('ul.nav li').removeClass('active');
    $('ul.nav li.nav-users').addClass('active');
  },
});
