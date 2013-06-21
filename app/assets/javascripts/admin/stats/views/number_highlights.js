$(document).ready(function() {
  });

var NumberHighlightsView = Backbone.Marionette.ItemView.extend({
  template: "#number_highlights",

  events: {
    "click a[data-toggle='facet-table']": "handleFacetTableClick",
  },

  onBeforeRender: function() {
    Handlebars.registerPartial('facetTable', $("#facet_table_partial").html());
  },

  handleFacetTableClick: function(event) {
    event.preventDefault();

    $(event.target).closest(".number-highlight").find("table").toggle();
  },
});
