//= require admin/stats/app
//= require admin/stats/controllers/map
//= require admin/stats/controllers/search
//= require admin/stats/controllers/users
//= require admin/stats/models/log
//= require admin/stats/models/pie_facet
//= require admin/stats/models/user
//= require admin/stats/models/region
//= require admin/stats/router
//= require admin/stats/views/filter
//= require admin/stats/views/interval_hits_chart
//= require admin/stats/views/loading_overlay
//= require admin/stats/views/log_table
//= require admin/stats/views/map
//= require admin/stats/views/map_table
//= require admin/stats/views/pie_facets
//= require admin/stats/views/users_table

Backbone.Marionette.TemplateCache.prototype.compileTemplate = function(rawTemplate) {
  return Handlebars.compile(rawTemplate);
};

google.setOnLoadCallback(function() {
  StatsApp.start();
});
