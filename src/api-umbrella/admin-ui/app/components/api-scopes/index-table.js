import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import escape from 'lodash-es/escape';

export default Component.extend({
  didInsertElement() {
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
        {
          data: 'admin_groups',
          title: 'Admin Groups',
          defaultContent: '-',
          render: DataTablesHelpers.renderLinkedListEscaped({
            editLink: '#/admin_group/',
            nameField: 'name',
          }),
        },
        {
          data: 'apis',
          title: 'API Backends',
          defaultContent: '-',
          render: DataTablesHelpers.renderLinkedListEscaped({
            editLink: '#/apis/',
            nameField: 'name',
          }),
        },
      ],
    });
  },
});
