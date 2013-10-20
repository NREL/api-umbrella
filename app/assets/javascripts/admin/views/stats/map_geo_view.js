Admin.StatsMapGeoView = Ember.View.extend({
  data: [],

  chartOptions: {
    width: 640,
    colorAxis: {
      colors: ["#B0DBFF", "#4682B4"],
    },
  },

  chartData: {
    cols: [],
    rows: []
  },

  didInsertElement: function() {
    this.chart = new google.visualization.GeoChart(this.$()[0]);
    google.visualization.events.addListener(this.chart, 'regionClick', _.bind(this.handleRegionClick, this));

    // On first load, refresh the data. Afterwards the observer should handle
    // refreshing.
    if(!this.dataTable) {
      this.refreshData();
    }

    $(window).on("resize", _.debounce(this.draw.bind(this), 100));
  },

  handleRegionClick: function(region) {
    this.set('controller.query.params.region', region.region);
  },

  refreshData: function() {
    this.chartData.rows = this.get('data') || [];
    this.chartData.cols = [
      {id: 'region', label: 'Region', type: 'string'},
      {id: 'startDate', label: 'Hits', type: 'number'},
    ];

    if(this.get('regionField') == "request_ip_city") {
      this.chartData.cols.unshift({id: 'latitude', label: 'Latitude', type: 'number'},
        {id: 'longitude', label: 'Longitude', type: 'number'});
    }

    this.chartOptions.region = this.get('controller.query.params.region');
    if(this.chartOptions.region.indexOf('US') === 0) {
      this.chartOptions.resolution = 'provinces';
    } else {
      this.chartOptions.resolution = 'countries';
    }

    if(this.chartOptions.region == 'world' || this.chartOptions.region == 'US') {
      this.chartOptions.displayMode = 'regions';
    } else {
      this.chartOptions.displayMode = 'markers';
    }

    this.dataTable = new google.visualization.DataTable(this.chartData);
    this.draw();
  }.observes('data'),

  draw: function() {
    this.chart.draw(this.dataTable, this.chartOptions);
  },
});
