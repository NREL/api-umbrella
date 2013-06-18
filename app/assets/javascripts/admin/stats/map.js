var StatsApp = Backbone.Router.extend({
  routes: {
    "": "defaultLoad",
    ":query": "refresh",
  },

  defaultQuery: 'tz=' + jstz.determine().name() +
    "&start=" + moment().subtract('days', 29).format('YYYY-MM-DD') +
    "&end=" + moment().format('YYYY-MM-DD') +
    "&region=world",

  initialize: function() {
    var stats = new Stats();
    this.filterView = new FilterView({ model: stats });
    new MapTable({ model: stats });
    new MapView({ model: stats });
  },

  defaultLoad: function() {
    this.filterView.setFromParams(this.defaultQuery);
    this.filterView.render();
    this.filterView.loadResults(this.defaultQuery);
  },

  refresh: function(query) {
    this.filterView.setFromParams(query);
    this.filterView.render();
    this.filterView.loadResults(query);
  },
});

var app;
google.setOnLoadCallback(function() {
  app = new StatsApp();

  Backbone.history.start({
    pushState: false,
    root: "/admin/stats/map/",
  })
});
