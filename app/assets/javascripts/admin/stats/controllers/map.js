var MapController = Marionette.Controller.extend({
  defaultQuery: {
    region: "world",
    tz: jstz.determine().name(),
    start: moment().subtract('days', 29).format('YYYY-MM-DD'),
    end: moment().format('YYYY-MM-DD'),
  },

  refreshFromQuery: function(query) {
    query = _.extend(this.defaultQuery, query);

    StatsApp.filterView.disableSearch();
    StatsApp.filterView.disableInterval();

    StatsApp.filterView.setFromQuery(query);
    this.loadResults(query);
  },

  loadResults: function(query) {
    StatsApp.loadingOverlayView.showSpinner();

    $.ajax({
      url: "/admin/stats/map.json",
      data: query,
      success: _.bind(this.handleLoadSuccess, this),
    });
  },

  handleLoadSuccess: function(data) {
    StatsApp.highlightsRegion.close();

    this.currentRegionField = data.region_field;

    StatsApp.vizRegion.show(new MapView(data));

    var regions = new Regions(_.clone(data.regions));
    StatsApp.tableRegion.show(new MapTable(regions));

    StatsApp.loadingOverlayView.hideSpinner();
  },
});
