var Stats = Backbone.Model.extend({
  url: "/admin/stats/data.json"
});

var StatsView = Backbone.View.extend({
});

var HitsChartView = Backbone.View.extend({
  el: "#hits_chart",

  events: {
    "resize window": "render",
  },

  chartOptions: {
    focusTarget: "category",
    width: "100%",
    chartArea: {
      width: "98%",
      height: "90%",
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
          {id: 'task', label: 'Employee Name', type: 'datetime'},
    {id: 'startDate', label: 'Hits', type: 'number'}],
    rows: []
  },

  initialize: function() {
    this.listenTo(this.model, "change", this.render);
    this.chart = new google.visualization.AreaChart(this.el);
    $(window).on("resize", this.render.bind(this));
  },

  render: function() {
    this.chartData.rows = this.model.get("hits");
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

    var data = new google.visualization.DataTable(this.chartData);
    this.chart.draw(data, this.chartOptions);
  }
});

var FacetChartView = Backbone.View.extend({
  chartOptions: {
    pieSliceText: 'none',
    enableInteractivity: false,
    height: 75,
    chartArea: {
      width: "100%",
      height: "100%",
    },
    legend: {
      position: 'none',
    }
  },

  chartData: {
    cols: [
          {id: 'task', label: 'Employee Name', type: 'string'},
    {id: 'startDate', label: 'Start Date', type: 'number'}],
    rows: []
  },

  initialize: function() {
    this.listenTo(this.model, "change", this.render);
    this.chart = new google.visualization.PieChart(this.el);
  },

  render: function() {
    this.chartData.rows = this.model.get(this.modelData).rows;
    var data = new google.visualization.DataTable(this.chartData);
    this.chart.draw(data, this.chartOptions);
  }
});

var FacetTableView = Backbone.View.extend({
  initialize: function() {
    this.template = Handlebars.compile($("#facet_table_template").html());

    this.listenTo(this.model, "change", this.render);
  },

  render: function() {
    this.$el.html(this.template(this.model.get(this.modelData)));
  },
});

var ResultsTableView = Backbone.View.extend({
  el: "#results_table",

  initialize: function() {
    this.template = Handlebars.compile($("#results_table_template").html());

    this.listenTo(this.model, "change", this.render);
  },

  render: function() {
    this.$el.html(this.template({ rows: this.model.get("results") }));
  },
});


var UserChartView = FacetChartView.extend({
  el: "#user_chart",
  modelData: "user_id",
});

var UserTableView = FacetTableView.extend({
  el: "#user_table",
  modelData: "user_id",
});


var ResponseStatusChartView = FacetChartView.extend({
  el: "#response_status_chart",
  modelData: "response_status",
});

var ResponseStatusTableView = FacetTableView.extend({
  el: "#response_status_table",
  modelData: "response_status",
});

var ResponseContentTypeChartView = FacetChartView.extend({
  el: "#response_content_type_chart",
  modelData: "response_content_type",
});

var ResponseContentTypeTableView = FacetTableView.extend({
  el: "#response_content_type_table",
  modelData: "response_content_type",
});

var RequestIpChartView = FacetChartView.extend({
  el: "#request_ip_chart",
  modelData: "request_ip",
});

var RequestIpTableView = FacetTableView.extend({
  el: "#request_ip_table",
  modelData: "request_ip",
});

var RequestMethodChartView = FacetChartView.extend({
  el: "#request_method_chart",
  modelData: "request_method",
});

var RequestMethodTableView = FacetTableView.extend({
  el: "#request_method_table",
  modelData: "request_method",
});


google.setOnLoadCallback(function() {
  var stats = new Stats();
  new HitsChartView({ model: stats });
  new ResultsTableView({ model: stats });

  new UserChartView({ model: stats });
  new UserTableView({ model: stats });

  new ResponseStatusChartView({ model: stats });
  new ResponseStatusTableView({ model: stats });
  new ResponseContentTypeChartView({ model: stats });
  new ResponseContentTypeTableView({ model: stats });

  new RequestIpChartView({ model: stats });
  new RequestIpTableView({ model: stats });

  new RequestMethodChartView({ model: stats });
  new RequestMethodTableView({ model: stats });


  new ResultsTableView({ model: stats });

  stats.fetch({
    success: function() {
      console.info("SUCCESS %o", arguments);
    },
    error: function() {
      console.info("ERROR %o", arguments);
    },
  });
});

