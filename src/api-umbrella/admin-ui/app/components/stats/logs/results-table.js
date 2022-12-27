// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { observes } from '@ember-decorators/object';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import clone from 'lodash-es/clone';
import compact from 'lodash-es/compact';
import escape from 'lodash-es/escape';
import extend from 'lodash-es/extend';
import tippy from 'tippy.js'

@classic
export default class ResultsTable extends Component {
  tagName = '';

  @action
  didInsert(element) {
    this.table = $(element).find('table').DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/logs.json',
        // Use POST for this endpoint, since the URLs can be very long and
        // exceed URL length limits in IE (and apparently Capybara too).
        type: 'POST',
        data: (data) => {
          return extend({}, data, this.backendQueryParamValues);
        },
      },
      drawCallback: () => {
        $(element).find('td').each(function() {
          if(this.scrollWidth > this.offsetWidth) {
            const $cell = $(this);
            $cell.attr('data-tippy-content', $cell.text());

            tippy($cell[0], {
              interactive: true,
              theme: 'light-border forced-wide',
              arrow: true,
              delay: 200,
            });
          }
        });
      },
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
          render: (email, type, data) => {
            if(type === 'display' && email && email !== '-') {
              let params = clone(this.presentQueryParamValues);
              params.search = compact([params.search, 'user_id:"' + data.user_id + '"']).join(' AND ');
              let link = '#/stats/logs?' + $.param(params);

              return '<a href="' + link + '">' + escape(email) + '</a>';
            }

            return email;
          },
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
  }

  // eslint-disable-next-line ember/no-observers
  @observes('backendQueryParamValues')
  refreshData() {
    if(this.table) {
      this.table.draw();
    }
  }

  @computed('backendQueryParamValues')
  get downloadUrl() {
    return '/admin/stats/logs.csv?' + $.param(this.backendQueryParamValues);
  }
}
