Admin.StatsUsersTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/users.json',
        data: _.bind(function(data) {
          var query = this.get('controller.query.params');
          return _.extend({}, data, query);
        }, this)
      },
      order: [[4, 'desc']],
      columns: [
        {
          data: 'email',
          title: 'Email',
          defaultContent: '-',
          render: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var params = _.clone(this.get('controller.query.params'));
              params.search = 'user_id:"' + data.id + '"';
              var link = '#/stats/logs/' + $.param(params);

              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          data: 'first_name',
          title: 'First Name',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'last_name',
          title: 'Last Name',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'created_at',
          type: 'date',
          title: 'Signed Up',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderTime,
        },
        {
          data: 'hits',
          title: 'Hits',
          defaultContent: '-',
          render: function(number, type) {
            if(type === 'display' && number && number !== '-') {
              return numeral(number).format('0,0');
            }

            return number;
          },
        },
        {
          data: 'last_request_at',
          type: 'date',
          title: 'Last Request',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderTime,
        },
        {
          data: 'use_description',
          title: 'Use Description',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderTime,
        },
      ]
    });
  },

  refreshData: function() {
    this.$().DataTable().draw();
  }.observes('controller.query.params.query', 'controller.query.params.search', 'controller.query.params.start_at', 'controller.query.params.end_at'),
});
