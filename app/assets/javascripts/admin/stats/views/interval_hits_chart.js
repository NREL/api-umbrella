var IntervalHitsChartView = Backbone.View.extend({
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

  initialize: function(chartRows) {
    this.chartData.rows = chartRows;
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

    this.chart = new google.visualization.AreaChart(this.el);
    $(window).on("resize", this.resize.bind(this));
  },

  onShow: function() {
    this.resize();
  },

  render: function() {
    this.chart.draw(this.dataTable, this.chartOptions);
  },

  resize: function() {
    // Redraw the chart on resize, so the percentage based width renders
    // properly.
    this.render();
  },
});
