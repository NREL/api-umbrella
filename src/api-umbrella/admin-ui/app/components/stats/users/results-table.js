import Ember from 'ember';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';

export default Ember.Component.extend({
  didInsertElement() {
    this.$().find('table').DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/users.json',
        data: function(data) {
          return _.extend({}, data, this.get('allQueryParamValues'));
        }.bind(this),
      },
      order: [[4, 'desc']],
      columns: [
        {
          data: 'email',
          title: 'Email',
          defaultContent: '-',
          render: function(email, type, data) {
            if(type === 'display' && email && email !== '-') {
              let params = _.clone(this.get('queryParamValues'));
              params.search = 'user_id:"' + data.id + '"';
              let link = '#/stats/logs?' + $.param(params);

              return '<a href="' + link + '">' + _.escape(email) + '</a>';
            }

            return email;
          }.bind(this),
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
          data: 'created_at',
          type: 'date',
          title: 'Signed Up',
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
        },
        {
          data: 'hits',
          title: 'Hits',
          defaultContent: '-',
          render: function(number, type) {
            if(type === 'display' && number && number !== '-') {
              return numeral(number).format('0,0');
            }

            return number;
          },
        },
        {
          data: 'last_request_at',
          type: 'date',
          title: 'Last Request',
          defaultContent: '-',
          render: DataTablesHelpers.renderTime,
        },
        {
          data: 'use_description',
          title: 'Use Description',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
      ]
    });
  },

  refreshData: Ember.observer('allQueryParamValues', function() {
    this.$().find('table').DataTable().draw();
  }),

  downloadUrl: Ember.computed('allQueryParamValues', function() {
    return '/admin/stats/users.csv?' + $.param(this.get('allQueryParamValues'));
  }),
});
