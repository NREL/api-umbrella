import Ember from 'ember';
import numeral from 'numeral';

export default Ember.Component.extend({
  session: Ember.inject.service(),

  didInsertElement() {
    this.$().find('table').DataTable({
      searching: false,
      order: [[1, 'desc']],
      data: this.get('results'),
      columns: [
        {
          data: 'path',
          title: 'Path',
          defaultContent: '-',
          render: function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              if(data.terminal) {
                return '<i class="fa fa-file-o fa-space-right"></i>' + _.escape(name);
              } else {
                let params = _.clone(this.get('presentQueryParamValues'));
                params.prefix = data.descendent_prefix;
                let link = '#/stats/drilldown?' + $.param(params);

                return '<a href="' + link + '"><i class="fa fa-folder-o fa-space-right"></i>' + _.escape(name) + '</a>';
              }
            }

            return name;
          }.bind(this),
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
      ],
    });
  },

  refreshData: Ember.observer('results', function() {
    let table = this.$().find('table').dataTable().api();
    table.clear();
    table.rows.add(this.get('results'));
    table.draw();
  }),

  downloadUrl: Ember.computed('backendQueryParamValues', function() {
    return '/api-umbrella/v1/analytics/drilldown.csv?api_key=' + this.get('session.data.authenticated.api_key') + '&' + $.param(this.get('backendQueryParamValues'));
  }),
});
