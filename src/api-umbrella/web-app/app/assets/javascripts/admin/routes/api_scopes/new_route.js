Admin.ApiScopesNewRoute = Admin.ApiScopesBaseRoute.extend({
  model: function() {
    return Admin.ApiScope.create();
  },
});

