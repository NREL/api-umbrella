import Ember from 'ember';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import usernameLabel from 'api-umbrella-admin-ui/utils/username-label';
import { t } from 'api-umbrella-admin-ui/utils/i18n';

export default Ember.Component.extend({
  session: Ember.inject.service('session'),

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
          title: usernameLabel(),
          defaultContent: '-',
          render: _.bind(function(username, type, data) {
            if(type === 'display' && username && username !== '-') {
              let link = '#/admins/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(username) + '</a>';
            }

            return username;
          }, this),
        },
        {
          data: 'group_names',
          name: 'Groups',
          title: t('Groups'),
          orderable: false,
          render: DataTablesHelpers.renderListEscaped,
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

    dataTable.on('draw.dt', function() {
      let params = dataTable.ajax.params();
      delete params.start;
      delete params.length;
      this.set('queryParams', params);
    }.bind(this));
  },

  downloadUrl: Ember.computed('queryParams', function() {
    let params = this.get('queryParams');
    if(params) {
      params = $.param(params);
    }

    return '/api-umbrella/v1/admins.csv?api_key=' + this.get('session.data.authenticated.api_key') + '&' + params;
  }),
});
