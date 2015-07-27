Admin.StatsMapGeoView = Ember.View.extend({
  data: [],

  chartOptions: {
    width: 640,
    colorAxis: {
      colors: ['#B0DBFF', '#4682B4'],
    },
  },

  chartData: {
    cols: [],
    rows: []
  },

  didInsertElement: function() {
    this.chart = new google.visualization.GeoChart(this.$()[0]);
    google.visualization.events.addListener(this.chart, 'regionClick', _.bind(this.handleRegionClick, this));
    google.visualization.events.addListener(this.chart, 'select', _.bind(this.handleCityClick, this));

    // On first load, refresh the data. Afterwards the observer should handle
    // refreshing.
    if(!this.dataTable) {
      this.refreshData();
    }

    $(window).on('resize', _.debounce(this.draw.bind(this), 100));
  },

  handleRegionClick: function(region) {
    this.set('controller.query.params.region', region.region);
  },

  handleCityClick: function() {
    if(this.get('model.region_field') === 'request_ip_city') {
      var selection = this.chart.getSelection();
      if(selection) {
        var rowIndex = selection[0].row;
        var region = this.dataTable.getValue(rowIndex, 2);

        var params = _.clone(this.get('controller.query.params'));
        params.search = 'request_ip_city:"' + region + '"';
        var router = this.get('controller.target.router');
        router.transitionTo('stats.logs', $.param(params));
      }
    }
  },

  refreshData: function() {
    this.chartData.rows = this.get('model.map_regions') || [];
    this.chartData.cols = [
      {id: 'region', label: 'Region', type: 'string'},
      {id: 'startDate', label: 'Hits', type: 'number'},
    ];

    if(this.get('model.region_field') === 'request_ip_city') {
      this.chartData.cols.unshift({id: 'latitude', label: 'Latitude', type: 'number'},
        {id: 'longitude', label: 'Longitude', type: 'number'});
    }

    this.chartOptions.region = this.get('controller.query.params.region');
    if(this.chartOptions.region.indexOf('US') === 0) {
      this.chartOptions.resolution = 'provinces';
    } else {
      this.chartOptions.resolution = 'countries';
    }

    if(this.chartOptions.region === 'world' || this.chartOptions.region === 'US') {
      this.chartOptions.displayMode = 'regions';
    } else {
      this.chartOptions.displayMode = 'markers';
    }

    this.dataTable = new google.visualization.DataTable(this.chartData);
    this.draw();
  }.observes('model.map_regions'),

  draw: function() {
    this.chart.draw(this.dataTable, this.chartOptions);
  },
});
