Admin.AdminsTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/admins.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'username',
          title: 'Username',
          defaultContent: '-',
          render: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var link = '#/admins/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          data: 'email',
          title: 'E-mail',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'group_names',
          title: 'Groups',
          render: Admin.DataTablesHelpers.renderListEscaped,
        },
        {
          data: 'last_sign_in_at',
          type: 'date',
          title: 'Last Signed In',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderTime,
        },
        {
          data: 'created_at',
          type: 'date',
          title: 'Created',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderTime,
        }
      ]
    });
  },
});
