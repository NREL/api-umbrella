Admin.ApiUsersEditRoute = Admin.ApiUsersBaseRoute.extend({
  model: function(params) {
    // Clear the record cache, so this is always fetched from the server (to
    // account for two users simultaneously editing the same record).
    Admin.ApiUser.clearCache();

    return Admin.ApiUser.find(params.apiUserId);
  },
});
