var Stats = Backbone.Model.extend({
  url: function() {
    return "/admin/stats/data.json?" + this.query;
  },

  setQuery: function(query) {
    this.query = query;
  },
});
