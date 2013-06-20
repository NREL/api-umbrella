var LogTableView = Backbone.View.extend({
  columns: [
    {
      name: "request_at",
      label: "Time",
      editable: false,
      cell: Backgrid.Extension.MomentCell.extend({
        displayFormat: "YYYY-MM-DD HH:mm:ss"
      })
    }, {
      name: "request_method",
      label: "Method",
      editable: false,
      cell: "string"
    }, {
      name: "request_url",
      label: "URL",
      editable: false,
      cell: "string"
    }, {
      name: "email",
      label: "User",
      editable: false,
      cell: "string"
    }, {
      name: "request_ip",
      label: "IP Address",
      editable: false,
      cell: "string"
    }, {
      name: "request_ip_country",
      label: "Country",
      editable: false,
      cell: "string"
    }, {
      name: "request_ip_region",
      label: "State",
      editable: false,
      cell: "string"
    }, {
      name: "request_ip_city",
      label: "City",
      editable: false,
      cell: "string"
    }, {
      name: "response_status",
      label: "Status",
      editable: false,
      cell: "string"
    }, {
      name: "response_content_type",
      label: "Content Type",
      editable: false,
      cell: "string"
    }, {
      name: "request_accept_encoding",
      label: "Accept Encoding",
      editable: false,
      cell: "string"
    }, {
      name: "request_user_agent",
      label: "User Agent",
      editable: false,
      cell: "string"
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
