Admin.ApiUsersTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bProcessing": true,
      "bServerSide": true,
      "bFilter": true,
      "bSearchable": false,
      "sAjaxSource": "/admin/api_users.json",
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
      "aaSorting": [[4, "desc"]],
      "aoColumns": [
        {
          mData: "email",
          sTitle: "E-mail",
          sDefaultContent: "-",
          mRender: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var link = '#/api_users/' + data._id + '/edit';
              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          mData: "first_name",
          sTitle: "First Name",
          sDefaultContent: "-",
        },
        {
          mData: "last_name",
          sTitle: "Last Name",
          sDefaultContent: "-",
        },
        {
          mData: "use_description",
          sTitle: "Purpose",
          sDefaultContent: "-",
        },
        {
          mData: "created_at",
          sType: "date",
          sTitle: "Created",
          sDefaultContent: "-",
          mRender: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return moment(time).format('YYYY-MM-DD HH:mm:ss');
            }

            return time;
          },
        },
        {
          mData: "api_key_preview",
          sTitle: "API Key",
          sDefaultContent: "-",
          bSortable: false,
        },
      ]
    });
  },
});
