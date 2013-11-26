Admin.ApiUsersIndexRoute = Admin.ApiUsersBaseRoute.extend({
  model: function() {
    return Admin.ApiUser.find();
  },
});
