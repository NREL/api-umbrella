import { computed, observer } from '@ember/object';

import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';

export default Component.extend({
  didInsertElement() {
    this.$().find('table').DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/logs.json',
        // Use POST for this endpoint, since the URLs can be very long and
        // exceed URL length limits in IE (and apparently Capybara too).
        type: 'POST',
        data: function(data) {
          return _.extend({}, data, this.get('backendQueryParamValues'));
        }.bind(this),
      },
      drawCallback: _.bind(function() {
        this.$().find('td').each(function() {
          if(this.scrollWidth > this.offsetWidth) {
            const $cell = $(this);
            $cell.prop('title', $cell.text());

            $cell.qtip({
              style: {
                classes: 'qtip-bootstrap qtip-forced-wide',
              },
              hide: {
                fixed: true,
                delay: 200,
              },
              position: {
                viewport: false,
                my: 'bottom center',
                at: 'top center',
              },
            });
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
          render: DataTablesHelpers.renderTime,
        },
        {
          data: 'request_method',
          title: 'Method',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_host',
          title: 'Host',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_url',
          title: 'URL',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'user_email',
          title: 'User',
          defaultContent: '-',
          render: function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              let params = _.clone(this.get('presentQueryParamValues'));
              params.search = _.compact([params.search, 'user_id:"' + data.user_id + '"']).join(' AND ');
              let link = '#/stats/logs?' + $.param(params);

              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }.bind(this),
        },
        {
          data: 'request_ip',
          title: 'IP Address',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_ip_country',
          title: 'Country',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_ip_region',
          title: 'State',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_ip_city',
          title: 'City',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'response_status',
          title: 'Status',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'gatekeeper_denied_code',
          title: 'Reason Denied',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'response_time',
          title: 'Response Time',
          defaultContent: '-',
          render(time, type) {
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
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_accept_encoding',
          title: 'Accept Encoding',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_user_agent',
          title: 'User Agent',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_user_agent_family',
          title: 'User Agent Family',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_user_agent_type',
          title: 'User Agent Type',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_referer',
          title: 'Referer',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'request_origin',
          title: 'Origin',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
      ],
    });
  },

  refreshData: observer('backendQueryParamValues', function() {
    this.$().find('table').DataTable().draw();
  }),

  downloadUrl: computed('backendQueryParamValues', function() {
    return '/admin/stats/logs.csv?' + $.param(this.get('backendQueryParamValues'));
  }),
});
