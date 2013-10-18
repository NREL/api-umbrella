Admin.StatsUsersController = Admin.StatsBaseController.extend({
});

Admin.StatsUsersDefaultController = Admin.StatsUsersController.extend({
  renderTemplate: function() {
    this.render('stats/users');
  }
});
