Admin.WebsiteBackendsNewRoute = Admin.WebsiteBackendsBaseRoute.extend({
  model: function() {
    return Admin.WebsiteBackend.create({
      serverPort: 80,
    });
  },
});

