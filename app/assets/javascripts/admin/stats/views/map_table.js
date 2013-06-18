var MapTable = Backbone.View.extend({
  el: "#table_container",

  columns: [
    {
      name: "name",
      label: "Name",
      editable: false,
      cell: "string",
    }, {
      name: "hits",
      label: "Hits",
      editable: false,
      cell: "integer"
    },
  ],

  initialize: function() {
    this.listenTo(this.model, "change", this.render);

    this.dataEntries = new PageableHits();
  },

  render: function() {
    this.dataEntries.fullCollection.reset();

    var regions = this.model.get('regions');
    for(var i = 0; i < regions.length; i++) {
      var region = regions[i];
      var name = region.c[region.c.length - 2];
      var hits = region.c[region.c.length - 1];
      this.dataEntries.add({
        name: (name.f) ? name.f : name.v,
        hits: hits.v,
      });
    }

    this.dataEntries.setPageSize(25);
    this.dataEntries.setSorting("hits", 1);
    this.dataEntries.fullCollection.sort();

    this.pageableGrid = new Backgrid.Grid({
      columns: this.columns,
      collection: this.dataEntries
    });

    this.paginator = new Backgrid.Extension.Paginator({
      collection: this.dataEntries
    });


    if(!this.blah) {
    this.$el.append(this.pageableGrid.render().$el);
    this.$el.append(this.paginator.render().$el);
    this.blah = true;
}
  },
});
