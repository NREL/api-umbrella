var Region = Backbone.Model.extend({
  initialize: function() {
    var c = this.get('c');

    // The last two records will always contain name and hits (for cities,
    // there are two lat/lon columns prefixed).
    var name = c[c.length - 2];
    var hits = c[c.length - 1];

    this.set({
      name: (name.f) ? name.f : name.v,
      region: name.v,
      hits: hits.v,
    });
  },
});

var Regions = Backbone.PageableCollection.extend({
  model: Region,
  state: {
    pageSize: 15
  },
  mode: "client"
});
