Admin.AdminScopesNewRoute = Admin.AdminScopesBaseRoute.extend({
  model: function() {
    return Admin.AdminScope.create();
  },
});

