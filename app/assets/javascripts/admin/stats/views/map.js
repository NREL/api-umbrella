var MapView = Backbone.Marionette.ItemView.extend({
  template: "#map_template",

  ui: {
    map: "#map",
    breadcrumbs: "#map_breadcrumbs",
  },

  events: {
    "resize window": "render",
  },

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

  initialize: function(data) {
    this.regionField = data.region_field;
    this.breadcrumbs = data.map_breadcrumbs;
    this.chartData.rows = data.regions;
  },

  onRender: function() {
    this.chart = new google.visualization.GeoChart(this.ui.map[0]);
    google.visualization.events.addListener(this.chart, 'regionClick', _.bind(this.handleRegionClick, this));

    this.chartData.cols = [
      {id: 'region', label: 'Region', type: 'string'},
      {id: 'startDate', label: 'Hits', type: 'number'},
    ];

    if(this.regionField == "request_ip_city") {
      this.chartData.cols.unshift({id: 'latitude', label: 'Latitude', type: 'number'},
        {id: 'longitude', label: 'Longitude', type: 'number'});
    }

    this.chartOptions.region = $('#region').val();
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

    var data = new google.visualization.DataTable(this.chartData);
    this.chart.draw(data, this.chartOptions);

    var breadcrumbsHtml = [];
    for(var i = 0; i < this.breadcrumbs.length; i++) {
      var breadcrumb = this.breadcrumbs[i];
      if(breadcrumb.region) {
        var currentQuery = StatsApp.router.getCurrentQuery();
        var query = _.extend({}, currentQuery, {
          region: breadcrumb.region,
        });

        var url = '#map/' + $.param(query);
        breadcrumbsHtml.push('<a href="' + url + '">' + breadcrumb.name + '</a>');
      } else {
        breadcrumbsHtml.push(breadcrumb.name);
      }
    }

    this.ui.breadcrumbs.html(breadcrumbsHtml.join(" / "))
  },

  handleRegionClick: function(region) {
    $('#region').val(region.region)
    StatsApp.filterView.submit();
  },
});
