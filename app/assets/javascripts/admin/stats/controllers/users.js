var UsersController = Marionette.Controller.extend({
  defaultQuery: {
    interval: 'day',
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
      url: "/admin/stats/users.json",
      data: query,
      success: _.bind(this.handleLoadSuccess, this),
    });
  },

  handleLoadSuccess: function(data) {
    StatsApp.vizRegion.close();
    StatsApp.highlightsRegion.close();

    var users = new Users(data.users);
    StatsApp.tableRegion.show(new UsersTableView(users));

    StatsApp.loadingOverlayView.hideSpinner();
  },
});
