import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';

export default Component.extend({
  busy: inject('busy'),
  session: inject('session'),

  didInsertElement() {
    const currentAdmin = this.get('session.data.authenticated.admin');

    const dataTable = this.$().find('table').DataTable({
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
    this.set('table', dataTable);

    dataTable.on('draw.dt', () => {
      let params = dataTable.ajax.params();
      delete params.start;
      delete params.length;
      this.set('csvQueryParams', params);
    });
  },

  downloadUrl: computed('csvQueryParams', function() {
    const params = $.param({
      ...(this.csvQueryParams || {}),
      api_key: this.get('session.data.authenticated.api_key'),
    });

    return `/api-umbrella/v1/apis.csv?${params}`;
  }),
});
