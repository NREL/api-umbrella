Admin.ApisRewriteFormController = Admin.NestedFormController.extend({
  titleBase: 'Rewrite',

  matcherTypeOptions: [
    { id: 'route', name: 'Route Pattern' },
    { id: 'regex', name: 'Regular Expression' },
  ],

  httpMethodOptions: [
    { id: 'any', name: 'Any' },
    { id: 'GET', name: 'GET' },
    { id: 'POST', name: 'POST' },
    { id: 'PUT', name: 'PUT' },
    { id: 'DELETE', name: 'DELETE' },
    { id: 'HEAD', name: 'HEAD' },
    { id: 'TRACE', name: 'TRACE' },
    { id: 'OPTIONS', name: 'OPTIONS' },
    { id: 'CONNECT', name: 'CONNECT' },
    { id: 'PATCH', name: 'PATCH' },
  ],
});
