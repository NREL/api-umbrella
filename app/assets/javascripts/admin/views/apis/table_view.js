Admin.ApisTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bProcessing": true,
      "bServerSide": true,
      "bFilter": true,
      "bSearchable": false,
      "sAjaxSource": "/admin/apis.json",
      "sDom": 'rft<"row-fluid"<"span3 table-info"i><"span6 table-pagination"p><"span3 table-length"l>>',
      "oLanguage": {
        "sProcessing": '<i class="icon-spinner icon-spin icon-large"></i>',
        "sSearch": "",
      },
      "fnInitComplete": function() {
        // Add a placeholder instead of the "Search:" label to the filter
        // input.
        $('.dataTables_filter input').attr("placeholder", "Search...");
      },
      "aaSorting": [[0, "asc"]],
      "aoColumns": [
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
          mRender: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/apis/' + data._id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          mData: "frontend_host",
          sTitle: "Host",
          sDefaultContent: "-",
        },
        {
          mData: "frontend_prefixes",
          sTitle: "Prefixes",
          sDefaultContent: "-",
        },
      ]
    });
  },
});
