Admin.StatsDrilldownChartView = Ember.View.extend({
  data: [],

  chartOptions: {
    pointSize: 0,
    lineWidth: 1,
    focusTarget: 'category',
    width: '100%',
    chartArea: {
      width: '95%',
      height: '88%',
      top: 0,
    },
    fontSize: 12,
    isStacked: true,
    areaOpacity: 0.2,
    vAxis: {
      gridlines: {
        count: 4
      },
      textStyle: {
        fontSize: 11,
      },
      textPosition: 'in',
    },
    hAxis: {
      format: 'MMM d',
      baselineColor: 'transparent',
      gridlines: {
        color: 'transparent',
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

    $(window).on('resize', _.debounce(this.draw.bind(this), 100));
  },

  refreshData: function() {
    this.chartData = this.get('data');
    for(var i = 0; i < this.chartData.rows.length; i++) {
      this.chartData.rows[i].c[0].v = new Date(this.chartData.rows[i].c[0].v);
    }

    // Show hours on the axis when viewing minutely date.
    switch(this.get('controller.query.params.interval')) {
      case 'minute':
        this.chartOptions.hAxis.format = 'MMM d h a';
        break;
      default:
        this.chartOptions.hAxis.format = 'MMM d';
        break;
    }

    // Show hours on the axis when viewing less than 2 days of hourly data.
    if(this.get('controller.query.params.interval') === 'hour') {
      var start = moment(this.get('controller.query.params.start_at'));
      var end = moment(this.get('controller.query.params.end_at'));
      var maxDuration = 2 * 24 * 60 * 60; // 2 days
      if(end.unix() - start.unix() <= maxDuration) {
        this.chartOptions.hAxis.format = 'MMM d h a';
      }
    }

    this.dataTable = new google.visualization.DataTable(this.chartData);
    this.draw();
  }.observes('data'),

  draw: function() {
    this.chart.draw(this.dataTable, this.chartOptions);
  },
});
