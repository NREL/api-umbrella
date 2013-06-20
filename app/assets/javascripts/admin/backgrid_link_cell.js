var LinkCell = Backgrid.LinkCell = Backgrid.StringCell.extend({
  className: "link-cell",

  uri: function() {
    return undefined;
  },

  render: function () {
    this.$el.empty();
    var formattedValue = this.formatter.fromRaw(this.model.get(this.column.get("name")));
    var uri = this.uri();
    this.$el.append($("<a>", {
      tabIndex: -1,
      href: uri,
      title: formattedValue,
    }).text(formattedValue));
    this.delegateEvents();
    return this;
  }
});
