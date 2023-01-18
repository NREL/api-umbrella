// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { inject } from '@ember/service';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import escape from 'lodash-es/escape';

@classic
export default class IndexTable extends Component {
  // eslint-disable-next-line ember/require-tagless-components
  tagName = 'div';

  @inject('busy')
  busy;

  @inject('session')
  session;

  @action
  didInsert(element) {
    const currentAdmin = this.session.data.authenticated.admin;

    const dataTable = $(element).find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/apis.json',
      pageLength: 50,
      rowCallback(row, data) {
        $(row).data('id', data.id);
      },
      order: [[0, 'asc']],
      columns: [
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: (name, type, data) => {
            if(type === 'display' && name && name !== '-') {
              let link = '#/apis/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(name) + '</a>';
            }

            return name;
          },
        },
        {
          data: 'frontend_host',
          title: 'Host',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'url_matches',
          title: 'Prefixes',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderList({
            nameField: 'frontend_prefix',
          }),
        },
        ...(currentAdmin.superuser ? [
          {
            data: 'organization_name',
            title: 'Organization Name',
            defaultContent: '-',
            render: DataTablesHelpers.renderEscaped,
          },
          {
            data: 'status_description',
            title: 'Status',
            defaultContent: '-',
            render: DataTablesHelpers.renderEscaped,
          },
          {
            data: 'root_api_scope.name',
            title: 'Root API Scope',
            defaultContent: '-',
            render: DataTablesHelpers.renderLink({
              editLink: '#/api_scopes/',
              idField: 'root_api_scope.id',
            }),
          },
          {
            data: 'api_scopes',
            title: 'API Scopes',
            defaultContent: '-',
            orderable: false,
            render: DataTablesHelpers.renderLinkedList({
              editLink: '#/api_scopes/',
              nameField: 'name',
            }),
          },
          {
            data: 'admin_groups',
            title: 'Admin Groups',
            defaultContent: '-',
            orderable: false,
            render: DataTablesHelpers.renderLinkedList({
              editLink: '#/admin_groups/',
              nameField: 'name',
            }),
          },
        ] : []),
      ],
    });

    dataTable.on('draw.dt', () => {
      let params = dataTable.ajax.params();
      delete params.start;
      delete params.length;
      this.set('csvQueryParams', params);
    });
  }

  @computed('csvQueryParams', 'session.data.authenticated.api_key')
  get downloadUrl() {
    const params = $.param({
      ...(this.csvQueryParams || {}),
      api_key: this.session.data.authenticated.api_key,
    });

    return `/api-umbrella/v1/apis.csv?${params}`;
  }
}
