var MapView = Backbone.View.extend({
  el: "#map_container",

  events: {
    "resize window": "render",
  },

  chartOptions: {
    colorAxis: {
      colors: ["#B0DBFF", "#4682B4"],
    },
  },

  chartData: {
    cols: [],
    rows: []
  },

  initialize: function() {
    this.listenTo(this.model, "change", this.render);
    this.chart = new google.visualization.GeoChart($("#map")[0]);
    google.visualization.events.addListener(this.chart, 'regionClick', _.bind(this.handleRegionClick, this));
    google.visualization.events.addListener(this.chart, 'ready', _.bind(this.handleReady, this));
  },

  render: function() {
    this.chartData.cols = [
      {id: 'region', label: 'Region', type: 'string'},
      {id: 'startDate', label: 'Hits', type: 'number'},
    ];

    var regionField = this.model.get("region_field");
    if(regionField == "request_ip_city") {
      this.chartData.cols.unshift({id: 'latitude', label: 'Latitude', type: 'number'},
        {id: 'longitude', label: 'Longitude', type: 'number'});
    }

    this.chartData.rows = this.model.get("regions");

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

    var breadcrumbs = this.model.get("map_breadcrumbs");
    var breadcrumbsHtml = [];
    for(var i = 0; i < breadcrumbs.length; i++) {
      var breadcrumb = breadcrumbs[i];
      if(breadcrumb.region) {
        var url = '#' + Backbone.history.fragment;
        url = url.replace(/((^|&)region)=[^&]*/, '$1=' + breadcrumb.region);
        breadcrumbsHtml.push('<a href="' + url + '">' + breadcrumb.name + '</a>');
      } else {
        breadcrumbsHtml.push(breadcrumb.name);
      }
    }

    $("#map_breadcrumbs").html(breadcrumbsHtml.join(" / "))
  },

  handleReady: function() {
    app.filterView.hideSpinner();
  },

  handleRegionClick: function(region) {
    $('#region').val(region.region)
    app.filterView.submit();
  },
});
