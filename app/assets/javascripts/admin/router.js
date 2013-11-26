Admin.Router.map(function() {
  this.resource("apis", { path: "/apis" }, function() {
    this.route("new");
    this.route("edit", { path: "/:apiId/edit" });
  });

  this.resource("api_users", { path: "/api_users" }, function() {
    this.route("new");
    this.route("edit", { path: "/:apiUserId/edit" });
  });

  this.resource("stats", { path: "/stats" }, function() {
    this.route("logs", { path: "/logs/*query" });
    this.route("logsDefault", { path: "/logs" });

    this.route("users", { path: "/users/*query" });
    this.route("usersDefault", { path: "/users" });

    this.route("map", { path: "/map/*query" });
    this.route("mapDefault", { path: "/map" });
  });
});
