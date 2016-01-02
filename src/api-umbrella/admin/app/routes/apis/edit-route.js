Admin.ApisEditRoute = Admin.ApisBaseRoute.extend({
  model: function(params) {
    // Clear the record cache, so this is always fetched from the server (to
    // account for two users simultaneously editing the same record).
    Admin.Api.clearCache();

    return Admin.Api.find(params.apiId);
  },
});

