Admin.ApisIndexRoute = Admin.ApisBaseRoute.extend({
  model: function() {
    return Admin.Api.find();
  },
});
