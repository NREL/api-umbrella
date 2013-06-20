var User = Backbone.Model.extend({
});

var Users = Backbone.PageableCollection.extend({
  model: User,
  state: {
    pageSize: 15
  },
  mode: "client"
});
