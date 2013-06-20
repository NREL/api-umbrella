var StatsRouter = Backbone.Router.extend({
  routes: {
    ":mode(/:query)": "refresh",
  },

  refresh: function(mode, query) {
    this.setCurrentMode(mode);
    this.setCurrentQuery(query);

    switch(this.getCurrentMode()) {
      case "users":
        StatsApp.usersController.refreshFromQuery(this.getCurrentQuery());
        break;
      case "drilldown":
        StatsApp.drilldownController.refreshFromQuery(this.getCurrentQuery());
        break;
      case "map":
        StatsApp.mapController.refreshFromQuery(this.getCurrentQuery());
        break;
      case "search":
        StatsApp.searchController.refreshFromQuery(this.getCurrentQuery());
        break;
    }
  },

  setCurrentMode: function(mode) {
    this.currentMode = mode;
  },

  getCurrentMode: function() {
    return this.currentMode;
  },

  setCurrentQuery: function(query) {
    this.currentQuery = {};
    if(query) {
      this.currentQuery = $.deparam(query);
    }
  },

  getCurrentQuery: function() {
    return this.currentQuery;
  },
});
