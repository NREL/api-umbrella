import { computed, observer } from '@ember/object';

import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import numeral from 'numeral';

export default Component.extend({
  didInsertElement() {
    this.$().find('table').DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/users.json',
        data: function(data) {
          return _.extend({}, data, this.get('backendQueryParamValues'));
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
              let params = _.clone(this.get('presentQueryParamValues'));
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
          render(number, type) {
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
      ],
    });
  },

  refreshData: observer('backendQueryParamValues', function() {
    this.$().find('table').DataTable().draw();
  }),

  downloadUrl: computed('backendQueryParamValues', function() {
    return '/admin/stats/users.csv?' + $.param(this.get('backendQueryParamValues'));
  }),
});
