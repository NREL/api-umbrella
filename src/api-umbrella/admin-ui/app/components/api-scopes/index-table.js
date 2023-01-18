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
  tagName = '';

  @inject()
  session;

  @action
  didInsert(element) {
    const currentAdmin = this.session.data.authenticated.admin;

    const dataTable = $(element).find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/api_scopes.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: (name, type, data) => {
            if(type === 'display' && name && name !== '-') {
              let link = '#/api_scopes/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(name) + '</a>';
            }

            return name;
          },
        },
        {
          data: 'host',
          title: 'Host',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'path_prefix',
          title: 'Path Prefix',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        ...(currentAdmin.superuser ? [
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
          {
            data: 'apis',
            title: 'API Backends',
            defaultContent: '-',
            orderable: false,
            render: DataTablesHelpers.renderLinkedList({
              editLink: '#/apis/',
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

    return `/api-umbrella/v1/api_scopes.csv?${params}`;
  }
}
