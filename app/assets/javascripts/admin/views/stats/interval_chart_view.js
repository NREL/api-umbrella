Admin.StatsIntervalChartView = Ember.View.extend({
  data: [],

  chartOptions: {
    focusTarget: "category",
    width: "100%",
    chartArea: {
      width: "95%",
      height: "88%",
      top: 0,
    },
    fontSize: 12,
    colors: ['#4682B4'],
    areaOpacity: 0.2,
    vAxis: {
      gridlines: {
        count: 4
      },
      textStyle: {
        fontSize: 11,
      },
      textPosition: "in",
    },
    hAxis: {
      format: "MMM d",
      baselineColor: "transparent",
      gridlines: {
        color: "transparent",
      },
    },
    legend: {
      position: 'none',
    }
  },

  chartData: {
    cols: [
      {id: 'date', label: 'Date', type: 'datetime'},
      {id: 'hits', label: 'Hits', type: 'number'},
    ],
    rows: []
  },

  didInsertElement: function() {
    this.chart = new google.visualization.AreaChart(this.$()[0]);

    // On first load, refresh the data. Afterwards the observer should handle
    // refreshing.
    if(!this.dataTable) {
      this.refreshData();
    }

    $(window).on("resize", _.debounce(this.draw.bind(this), 100));
  },

  refreshData: function() {
    this.chartData.rows = this.get('data') || [];
    for(var i = 0; i < this.chartData.rows.length; i++) {
      this.chartData.rows[i].c[0].v = new Date(this.chartData.rows[i].c[0].v);
    }

    if(this.chartData.rows.length < 100) {
      this.chartOptions.pointSize = 8
      this.chartOptions.lineWidth = 4
    } else {
      this.chartOptions.pointSize = 0
      this.chartOptions.lineWidth = 3
    }

    this.dataTable = new google.visualization.DataTable(this.chartData);
    this.draw();
  }.observes('data'),

  draw: function() {
    this.chart.draw(this.dataTable, this.chartOptions);
  },
});
