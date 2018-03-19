import $ from 'jquery';
import Component from '@ember/component';

export default Component.extend({
  didInsertElement() {
    this.set('table', this.$().find('table').DataTable({
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
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              let link = '#/website_backends/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
      ],
    }));
  },
});
