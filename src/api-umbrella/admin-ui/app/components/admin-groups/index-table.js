// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import escape from 'lodash-es/escape';

@classic
export default class IndexTable extends Component {
  tagName = '';

  @action
  didInsert(element) {
    $(element).find('table').DataTable({
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
          data: 'api_scope_display_names',
          title: 'API Scopes',
          orderable: false,
          render: DataTablesHelpers.renderListEscaped,
        },
        {
          data: 'permission_display_names',
          title: 'Access',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderListEscaped,
        },
        {
          data: 'admin_usernames',
          title: 'Admins',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderListEscaped,
        },
      ],
    });
  }
}
