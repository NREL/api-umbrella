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
      ajax: '/api-umbrella/v1/users.json',
      pageLength: 50,
      order: [[4, 'desc']],
      columns: [
        {
          data: 'email',
          title: 'E-mail',
          defaultContent: '-',
          render: (email, type, data) => {
            if(type === 'display' && email && email !== '-') {
              let link = '#/api_users/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(email) + '</a>';
            }

            return email;
          },
        },
        {
          data: 'first_name',
          title: 'First Name',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'last_name',
          title: 'Last Name',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'use_description',
          title: 'Purpose',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'created_at',
          type: 'date',
          title: 'Created',
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
        },
        {
          data: 'registration_source',
          title: 'Registration Source',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'api_key_preview',
          title: 'API Key',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderEscaped,
        },
      ],
    });
  }
}
