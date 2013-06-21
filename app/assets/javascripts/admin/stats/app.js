StatsApp = new Backbone.Marionette.Application();

StatsApp.addInitializer(function(options){
  StatsApp.addRegions({
    filterRegion: "#filter_region",
    vizRegion: "#viz_region",
    highlightsRegion: "#highlight_region",
    tableRegion: "#table_region",
  });

  StatsApp.loadingOverlayView = new LoadingOverlayView();

  StatsApp.filterView = new FilterView();
  StatsApp.filterRegion.show(StatsApp.filterView);

  StatsApp.usersController = new UsersController();
  StatsApp.mapController = new MapController();
  StatsApp.searchController = new SearchController();

  StatsApp.router = new StatsRouter();
  Backbone.history.start({
    pushState: false,
    root: "/admin/stats/",
  })
});
