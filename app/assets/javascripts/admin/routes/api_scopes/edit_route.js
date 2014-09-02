Admin.ApiScopesEditRoute = Admin.ApiScopesBaseRoute.extend({
  model: function(params) {
    return Admin.ApiScope.find(params.apiScopeId);
  },
});
