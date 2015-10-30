Admin.AdminsEditRoute = Admin.AdminsBaseRoute.extend({
  model: function(params) {
    // Clear the record cache, so this is always fetched from the server (to
    // account for two users simultaneously editing the same record).
    Admin.Admin.clearCache();

    return Admin.Admin.find(params.adminId);
  },
});
