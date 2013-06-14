var StatsApp = Backbone.Router.extend({
  routes: {
    "": "defaultLoad",
    ":query": "refresh",
  },

  defaultQuery: "interval=day" +
    '&tz=' + jstz.determine().name() +
    "&start=" + moment().subtract('days', 29).format('YYYY-MM-DD') +
    "&end=" + moment().format('YYYY-MM-DD'),

  initialize: function() {
    var stats = new Stats();
    this.chartFormView = new ChartFormView({ model: stats });
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
  },

  defaultLoad: function() {
    this.chartFormView.setFromParams(this.defaultQuery);
    this.chartFormView.render();
    this.chartFormView.loadResults(this.defaultQuery);
  },

  refresh: function(query) {
    this.chartFormView.setFromParams(query);
    this.chartFormView.render();
    this.chartFormView.loadResults(query);
  },
});


var Stats = Backbone.Model.extend({
  url: function() {
    return "/admin/stats/data.json?" + this.query;
  },

  setQuery: function(query) {
    this.query = query;
  },
});

var StatsView = Backbone.View.extend({
});

var ChartFormView = Backbone.View.extend({
  el: "#chart_form",

  events: {
    "click #interval_buttons button": "handleIntervalChange",
    "change select": "submit",
  },

  datePickerRanges: {
    'Today': [
      moment().startOf('day'),
      moment().endOf('day'),
    ],
    'Yesterday': [
      moment().subtract('days', 1),
      moment().subtract('days', 1).endOf('day'),
    ],
    'Last 7 Days': [
      moment().subtract('days', 6),
      moment().endOf('day'),
    ],
    'Last 30 Days': [
      moment().subtract('days', 29).startOf('day'),
      moment().endOf('day'),
    ],
    'This Month': [
      moment().startOf('month'),
      moment().endOf('month'),
    ],
    'Last Month': [
      moment().subtract('month', 1).startOf('month'),
      moment().subtract('month', 1).endOf('month'),
    ]
  },

  initialize: function() {
  },

  render: function() {
    $('#reportrange').daterangepicker({
        ranges: this.datePickerRanges,
        startDate: moment(this.$el.find("#start").val(), 'YYYY-MM-DD'),
        endDate: moment(this.$el.find("#end").val(), 'YYYY-MM-DD'),
      }, _.bind(this.handleDateRangeChange, this));
  },

  setFromParams: function(params) {
    this.$el.deserialize(params, { noEvents: true });

    var interval = this.$el.find("#interval").val();
    this.$el.find("button[value='" + interval + "']").button('toggle');

    var start = moment(this.$el.find("#start").val());
    var end = moment(this.$el.find("#end").val());
    this.setDateRangeDisplay(start, end);
  },

  submit: function() {
    var query = this.$el.serialize();
    app.navigate(query);
    this.loadResults(query);
  },

  loadResults: function(query) {
    this.model.setQuery(query);
    this.model.fetch({
      success: function() {
        console.info("SUCCESS %o", arguments);
      },
      error: function() {
        console.info("ERROR %o", arguments);
      },
    });
  },

  handleIntervalChange: function(event) {
    $("#interval").val($(event.target).val());
    this.submit();
  },

  setDateRange: function(start, end) {
    $("#start").val(start.format("YYYY-MM-DD"));
    $("#end").val(end.format("YYYY-MM-DD"));
    this.setDateRangeDisplay(start, end);
  },

  setDateRangeDisplay: function(start, end) {
    $('#reportrange span').html(start.format('MMM D, YYYY') + ' - ' + end.format('MMM D, YYYY'));
  },

  handleDateRangeChange: function(start, end) {
    this.setDateRange(start, end);
    this.submit();
  },
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


var app;
google.setOnLoadCallback(function() {
  app = new StatsApp();

  Backbone.history.start({
    pushState: false,
    root: "/admin/stats/",
  })
});
