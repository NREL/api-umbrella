Admin.LogsTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/logs.json',
        // Use POST for this endpoint, since the URLs can be very long and
        // exceed URL length limits in IE (and apparently Capybara too).
        type: 'POST',
        data: _.bind(function(data) {
          var query = this.get('controller.query.params');
          return _.extend({}, data, query);
        }, this)
      },
      drawCallback: _.bind(function() {
        this.$().find('td').truncate({
          width: 400,
          addtitle: true,
          addclass: 'truncated'
        });

        this.$().find('.truncated').qtip({
          style: {
            classes: 'qtip-bootstrap qtip-forced-wide',
          },
          hide: {
            fixed: true,
            delay: 200
          },
          position: {
            viewport: false,
            my: 'bottom center',
            at: 'top center'
          }
        });
      }, this),
      order: [[0, 'desc']],
      columns: [
        {
          data: 'request_at',
          type: 'date',
          title: 'Time',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderTime,
        },
        {
          data: 'request_method',
          title: 'Method',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_host',
          title: 'Host',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_url',
          title: 'URL',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'user_email',
          title: 'User',
          defaultContent: '-',
          render: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              var params = _.clone(this.get('controller.query.params'));
              params.search = _.compact([params.search, 'user_id:"' + data.user_id + '"']).join(' AND ');
              var link = '#/stats/logs/' + $.param(params);

              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          data: 'request_ip',
          title: 'IP Address',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_ip_country',
          title: 'Country',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_ip_region',
          title: 'State',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_ip_city',
          title: 'City',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'response_status',
          title: 'Status',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'response_time',
          title: 'Response Time',
          defaultContent: '-',
          render: function(time, type) {
            if(type === 'display' && time && time !== '-') {
              return time + ' ms';
            }

            return time;
          },
        },
        {
          data: 'response_content_type',
          title: 'Content Type',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_accept_encoding',
          title: 'Accept Encoding',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_user_agent',
          title: 'User Agent',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
      ]
    });
  },

  refreshData: function() {
    this.$().DataTable().draw();
  }.observes('controller.query.params.query', 'controller.query.params.search', 'controller.query.params.start_at', 'controller.query.params.end_at'),
});
