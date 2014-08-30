Admin.AdminGroupsNewRoute = Admin.AdminGroupsBaseRoute.extend({
  model: function() {
    return Admin.AdminGroup.create();
  },
});

