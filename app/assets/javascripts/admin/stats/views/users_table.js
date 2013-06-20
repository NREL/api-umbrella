var UsersTableView = Backbone.View.extend({
  columns: [
    {
      name: "email",
      label: "User",
      editable: false,
      cell: LinkCell.extend({
        uri: function() {
          var query = _.extend({}, StatsApp.router.getCurrentQuery(), {
            search: 'user_id:' + this.model.get('id'),
          });

          return '#search/' + $.param(query);
        },
      }),
    }, {
      name: "hits",
      label: "Hits",
      editable: false,
      cell: "integer"
    },
  ],

  initialize: function(collection) {
    this.grid = new Backgrid.Grid({
      columns: this.columns,
      collection: collection,
    });

    this.paginator = new Backgrid.Extension.Paginator({
      collection: collection,
    });
  },

  render: function() {
    this.$el.append(this.grid.render().$el);
    this.$el.append(this.paginator.render().$el);
  },
});
