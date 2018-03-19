import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';

export default Component.extend({
  didInsertElement() {
    this.$().find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/users.json',
      pageLength: 50,
      order: [[4, 'desc']],
      columns: [
        {
          data: 'email',
          title: 'E-mail',
          defaultContent: '-',
          render: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              let link = '#/api_users/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
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
  },
});
