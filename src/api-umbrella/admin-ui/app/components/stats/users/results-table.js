// eslint-disable-next-line ember/no-observers
import { computed, observer } from '@ember/object';

import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import clone from 'lodash-es/clone';
import escape from 'lodash-es/escape';
import extend from 'lodash-es/extend';
import numeral from 'numeral';

export default Component.extend({
  didInsertElement() {
    this.$().find('table').DataTable({
      searching: false,
      serverSide: true,
      ajax: {
        url: '/admin/stats/users.json',
        data: function(data) {
          return extend({}, data, this.backendQueryParamValues);
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
              let params = clone(this.presentQueryParamValues);
              params.search = 'user_id:"' + data.id + '"';
              let link = '#/stats/logs?' + $.param(params);

              return '<a href="' + link + '">' + escape(email) + '</a>';
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

  // eslint-disable-next-line ember/no-observers
  refreshData: observer('backendQueryParamValues', function() {
    this.$().find('table').DataTable().draw();
  }),

  downloadUrl: computed('backendQueryParamValues', function() {
    return '/admin/stats/users.csv?' + $.param(this.backendQueryParamValues);
  }),
});
