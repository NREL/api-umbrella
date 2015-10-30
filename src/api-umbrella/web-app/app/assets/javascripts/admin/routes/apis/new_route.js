Admin.ApisNewRoute = Admin.ApisBaseRoute.extend({
  model: function() {
    return Admin.Api.create({
      frontendHost: 'api.data.gov',
    });
  },
});

