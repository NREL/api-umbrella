import $ from 'jquery';
import Component from '@ember/component';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';

export default Component.extend({
  session: inject('session'),

  didInsertElement() {
    const dataTable = this.$().find('table').DataTable({
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
    });

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

    return `/api-umbrella/v1/website_backends.csv?${params}`;
  }),
});
