import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import I18n from 'i18n-js';
import { computed } from '@ember/object';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';

export default Component.extend({
  session: inject('session'),

  didInsertElement() {
    let dataTable = this.$().find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/admins.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'username',
          name: 'Username',
          title: I18n.t('mongoid.attributes.admin.username'),
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
          data: 'group_names',
          name: 'Groups',
          title: 'Groups',
          orderable: false,
          render: DataTablesHelpers.renderListEscaped,
        },
        {
          data: 'current_sign_in_at',
          type: 'date',
          name: 'Last Signed In',
          title: 'Last Signed In',
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
        },
        {
          data: 'created_at',
          type: 'date',
          name: 'Created',
          title: 'Created',
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
        },
      ],
    });

    dataTable.on('draw.dt', function() {
      let params = dataTable.ajax.params();
      delete params.start;
      delete params.length;
      this.set('queryParams', params);
    }.bind(this));
  },

  downloadUrl: computed('queryParams', 'session.data.authenticated.api_key', function() {
    let params = this.queryParams;
    if(params) {
      params = $.param(params);
    }

    return '/api-umbrella/v1/admins.csv?api_key=' + this.session.data.authenticated.api_key + '&' + params;
  }),
});
