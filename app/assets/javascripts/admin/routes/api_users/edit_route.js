Admin.ApiUsersEditRoute = Admin.ApiUsersBaseRoute.extend({
  model: function(params) {
    return Admin.ApiUser.find(params.apiUserId);
  },
});
