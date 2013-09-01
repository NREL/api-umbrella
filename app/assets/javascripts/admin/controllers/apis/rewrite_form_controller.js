Admin.ApisRewriteFormController = Admin.NestedFormController.extend({
  titleBase: 'Rewrite',

  matcherOptions: [
    { id: "prefix", name: "Prefix" },
    { id: "pattern", name: "Route Pattern" },
  ],

  httpMethodOptions: [
    { id: "any", name: "Any" },
    { id: "GET", name: "GET" },
    { id: "POST", name: "POST" },
    { id: "PUT", name: "PUT" },
    { id: "DELETE", name: "DELETE" },
    { id: "HEAD", name: "HEAD" },
    { id: "TRACE", name: "TRACE" },
    { id: "OPTIONS", name: "OPTIONS" },
    { id: "CONNECT", name: "CONNECT" },
    { id: "PATCH", name: "PATCH" },
  ],
});
