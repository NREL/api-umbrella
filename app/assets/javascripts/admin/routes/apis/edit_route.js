Admin.ApisEditRoute = Admin.ApisBaseRoute.extend({
  model: function(params) {
    return Admin.Api.find(params.apiId);
  },
});

