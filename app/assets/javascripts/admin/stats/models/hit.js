var Hit = Backbone.Model.extend({
});

var PageableHits = Backbone.PageableCollection.extend({
  model: Hit,
  state: {
    pageSize: 15
  },
  mode: "client"
});
