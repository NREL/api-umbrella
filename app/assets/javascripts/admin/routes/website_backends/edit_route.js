Admin.WebsiteBackendsEditRoute = Admin.WebsiteBackendsBaseRoute.extend({
  model: function(params) {
    // Clear the record cache, so this is always fetched from the server (to
    // account for two users simultaneously editing the same record).
    Admin.WebsiteBackend.clearCache();

    return Admin.WebsiteBackend.find(params.websiteBackendId);
  },
});

