import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';

export default Component.extend({
  session: inject('session'),

  didInsertElement() {
    const currentAdmin = this.get('session.data.authenticated.admin');

    this.$().find('table').DataTable({
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
  },
});
