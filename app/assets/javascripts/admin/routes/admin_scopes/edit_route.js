Admin.AdminScopesEditRoute = Admin.AdminScopesBaseRoute.extend({
  model: function(params) {
    return Admin.AdminScope.find(params.adminScopeId);
  },
});
