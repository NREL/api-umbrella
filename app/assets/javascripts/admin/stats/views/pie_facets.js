var PieFacetView = Backbone.Marionette.ItemView.extend({
  template: "#pie_facet_template",
  className: "span3",

  ui: {
    chartContainer: ".facet-chart",
  },

  chartOptions: {
    pieSliceText: 'none',
    height: 100,
    chartArea: {
      width: "85%",
      height: "85%",
    },
    legend: {
      position: 'none',
    }
  },

  chartData: {
    cols: [
      {id: 'term', label: 'Term', type: 'string'},
      {id: 'hits', label: 'Hits', type: 'number'},
    ],
    rows: []
  },

  onRender: function() {
    this.chartData.rows = this.model.get('rows');
    this.chart = new google.visualization.PieChart(this.ui.chartContainer[0]);

    var data = new google.visualization.DataTable(this.chartData);
    this.chart.draw(data, this.chartOptions);
  },
});

var PieFacetListView = Backbone.Marionette.CompositeView.extend({
  itemView: PieFacetView,
  itemViewContainer: ".row-fluid",
  template: "#pie_facet_list_template",

  appendHtml: function(collectionView, itemView, index){
    if(index % 4 === 0) {
      collectionView.$el.append('<div class="row-fluid"></div>');
    }

    collectionView.$el.find(".row-fluid:last-child").append(itemView.el);
  }
});
