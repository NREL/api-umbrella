Admin.AdminScopesTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bServerSide": true,
      "sAjaxSource": "/admin/admin_scopes.json",
      "iDisplayLength": 50,
      "aaSorting": [[0, "asc"]],
      "aoColumns": [
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
          mRender: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/admin_scopes/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          mData: "host",
          sTitle: "Host",
          sDefaultContent: "-",
        },
        {
          mData: "path_prefix",
          sTitle: "Path Prefix",
          sDefaultContent: "-",
        }
      ]
    });
  },
});
