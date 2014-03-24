Admin.AdminsEditRoute = Admin.AdminsBaseRoute.extend({
  model: function(params) {
    return Admin.Admin.find(params.adminId);
  },
});
