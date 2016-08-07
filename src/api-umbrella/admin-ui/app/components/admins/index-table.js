import Ember from 'ember';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';

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
          title: 'Username',
          defaultContent: '-',
          render: _.bind(function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              let link = '#/admins/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }, this),
        },
        {
          data: 'email',
          name: 'E-mail',
          title: 'E-mail',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'name',
          name: 'Name',
          title: 'Name',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'group_names',
          name: 'Groups',
          title: 'Groups',
          orderable: false,
          render: DataTablesHelpers.renderListEscaped,
        },
        {
          data: 'last_sign_in_at',
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

  downloadUrl: Ember.computed('queryParams', function() {
    let params = this.get('queryParams');
    if(params) {
      params = $.param(params);
    }

    return '/api-umbrella/v1/admins.csv?api_key=' + this.get('session.data.authenticated.api_key') + '&' + params;
  }),
});
