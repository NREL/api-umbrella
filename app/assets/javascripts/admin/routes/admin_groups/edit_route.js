Admin.AdminGroupsEditRoute = Admin.AdminGroupsBaseRoute.extend({
  model: function(params) {
    return Admin.AdminGroup.find(params.adminGroupId);
  },
});
