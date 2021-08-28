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
    const dataTable = $(element).find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/admin_groups.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: (name, type, data) => {
            if(type === 'display' && name && name !== '-') {
              let link = '#/admin_groups/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(name) + '</a>';
            }

            return name;
          },
        },
        {
          data: 'api_scopes',
          title: 'API Scopes',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderLinkedList({
            editLink: '#/api_scopes/',
            nameField: (value) => {
              return `${value.name} - ${value.host}${value.path_prefix}`;
            },
          }),
        },
        {
          data: 'permission_display_names',
          title: 'Access',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderList(),
        },
        {
          data: 'admins',
          title: 'Admins',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderLinkedList({
            editLink: '#/admins/',
            nameField: 'username',
          }),
        },
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

    return `/api-umbrella/v1/admin_groups.csv?${params}`;
  }
}
