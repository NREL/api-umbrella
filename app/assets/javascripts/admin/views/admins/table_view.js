Admin.AdminsTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bServerSide": true,
      "sAjaxSource": "/admin/admins.json",
      "iDisplayLength": 50,
      "aaSorting": [[0, "asc"]],
      "aoColumns": [
        {
          mData: "username",
          sTitle: "Username",
          sDefaultContent: "-",
          mRender: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var link = '#/admins/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          mData: "email",
          sTitle: "E-mail",
          sDefaultContent: "-",
        },
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
        },
        {
          mData: "last_sign_in_at",
          sType: "date",
          sTitle: "Last Signed In",
          sDefaultContent: "-",
          mRender: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return moment(time).format('YYYY-MM-DD HH:mm:ss');
            }

            return time;
          },
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
        }
      ]
    });
  },
});
