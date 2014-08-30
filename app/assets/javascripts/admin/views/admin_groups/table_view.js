Admin.AdminGroupsTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bServerSide": true,
      "sAjaxSource": "/admin/admin_groups.json",
      "iDisplayLength": 50,
      "aaSorting": [[0, "asc"]],
      "aoColumns": [
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
          mRender: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/admin_groups/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          mData: "scope_display_name",
          sTitle: "Scope",
          sDefaultContent: "-",
        },
        {
          mData: "access",
          sTitle: "Access",
          sDefaultContent: "-",
          mRender: function(access, type, data) {
            if(type === 'display' && access && access !== '-') {
              return access.join(', ');
            }

            return access;
          },
        }
      ]
    });
  },
});
