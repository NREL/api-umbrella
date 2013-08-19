Admin.Router.map(function() {
  this.resource("apis", { path: "/apis" }, function() {
    this.route("new");
    this.route("edit", { path: "/:apiId/edit" });
  });
});

console.info(Admin.Router.router.recognizer);
