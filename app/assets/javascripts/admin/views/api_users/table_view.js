Admin.ApiUsersTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/users.json',
      pageLength: 50,
      order: [[4, 'desc']],
      columns: [
        {
          data: 'email',
          title: 'E-mail',
          defaultContent: '-',
          render: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var link = '#/api_users/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          data: 'first_name',
          title: 'First Name',
          defaultContent: '-',
        },
        {
          data: 'last_name',
          title: 'Last Name',
          defaultContent: '-',
        },
        {
          data: 'use_description',
          title: 'Purpose',
          defaultContent: '-',
        },
        {
          data: 'created_at',
          type: 'date',
          title: 'Created',
          defaultContent: '-',
          render: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return moment(time).format('YYYY-MM-DD HH:mm:ss');
            }

            return time;
          },
        },
        {
          data: 'api_key_preview',
          title: 'API Key',
          defaultContent: '-',
          orderable: false,
        },
      ]
    });
  },
});
