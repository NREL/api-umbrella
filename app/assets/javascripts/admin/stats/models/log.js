var Log = Backbone.Model.extend({
});

var Logs = Backbone.PageableCollection.extend({
  model: Log,
  state: {
    pageSize: 15
  },
  mode: "client"
});
