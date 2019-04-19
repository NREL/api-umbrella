import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';
import { t } from 'api-umbrella-admin-ui/utils/i18n';
import usernameLabel from 'api-umbrella-admin-ui/utils/username-label';

export default Component.extend({
  session: inject('session'),

  didInsertElement() {
    const dataTable = this.$().find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/admins.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'username',
          name: 'Username',
          title: usernameLabel(),
          defaultContent: '-',
          render: (username, type, data) => {
            if(type === 'display' && username && username !== '-') {
              let link = '#/admins/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(username) + '</a>';
            }

            return username;
          },
        },
        {
          data: 'groups',
          name: 'Groups',
          title: t('Groups'),
          orderable: false,
          render: (value, type, row) => {
            if(row.superuser === true) {
              // For superusers, append this to the list of groups for display
              // purposes (even though it isn't really a group and can't be
              // linked, like the other admin groups).
              value.push({
                name: t('Superuser'),
              });
            }

            return DataTablesHelpers.renderLinkedList({
              editLink: '#/admin_groups/',
              nameField: 'name',
            })(value, type);
          },
        },
        {
          data: 'current_sign_in_at',
          type: 'date',
          name: 'Last Signed In',
          title: t('Last Signed In'),
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
        },
        {
          data: 'created_at',
          type: 'date',
          name: 'Created',
          title: t('Created'),
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
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

    return `/api-umbrella/v1/admins.csv?${params}`;
  }),
});
