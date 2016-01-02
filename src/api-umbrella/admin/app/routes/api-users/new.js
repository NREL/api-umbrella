Admin.ApiUsersNewRoute = Admin.ApiUsersBaseRoute.extend({
  model: function() {
    return Admin.ApiUser.create();
  },
});

export default undefined;
