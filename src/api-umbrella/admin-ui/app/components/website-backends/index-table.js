// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import escape from 'lodash-es/escape';

@classic
export default class IndexTable extends Component {
  tagName = '';

  @action
  didInsert(element) {
    this.set('table', $(element).find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/website_backends.json',
      pageLength: 50,
      rowCallback(row, data) {
        $(row).data('id', data.id);
      },
      order: [[0, 'asc']],
      columns: [
        {
          data: 'frontend_host',
          title: 'Host',
          defaultContent: '-',
          render: (name, type, data) => {
            if(type === 'display' && name && name !== '-') {
              let link = '#/website_backends/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(name) + '</a>';
            }

            return name;
          },
        },
      ],
    }));
  }
}
