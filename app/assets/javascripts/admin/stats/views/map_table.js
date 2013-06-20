var MapTable = Backbone.View.extend({
  columns: [
    {
      name: "name",
      label: "Name",
      editable: false,
      cell: LinkCell.extend({
        uri: function() {
          var uri;
          var currentQuery = StatsApp.router.getCurrentQuery();
          var newRegion = this.model.get('region');
          if(StatsApp.mapController.currentRegionField == 'request_ip_city') {
            var query = _.extend({}, currentQuery, {
              search: 'request_ip_city:' + newRegion,
            });

            delete query.region;

            uri = '#search/' + $.param(query);
          } else {
            if(currentQuery.region == 'US') {
              newRegion = 'US-' + newRegion;
            }

            var query = _.extend({}, currentQuery, {
              region: newRegion,
            });

            uri = '#map/' + $.param(query);
          }

          return uri;
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
