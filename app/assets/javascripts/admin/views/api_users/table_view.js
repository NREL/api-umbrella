Admin.ApiUsersTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bServerSide": true,
      "sAjaxSource": "/admin/api_users.json",
      "iDisplayLength": 50,
      "aaSorting": [[4, "desc"]],
      "aoColumns": [
        {
          mData: "email",
          sTitle: "E-mail",
          sDefaultContent: "-",
          mRender: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var link = '#/api_users/' + data.id + '/edit';
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
