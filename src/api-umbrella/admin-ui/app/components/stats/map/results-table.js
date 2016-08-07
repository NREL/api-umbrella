import Ember from 'ember';
import numeral from 'numeral';

export default Ember.Component.extend({
  didInsertElement() {
    this.$().find('table').DataTable({
      searching: false,
      order: [[1, 'desc']],
      data: this.get('regions'),
      columns: [
        {
          data: 'name',
          title: 'Location',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              let link;
              let params = _.clone(this.get('queryParamValues'));
              if(this.get('regionField') === 'request_ip_city') {
                delete params.region;
                params.search = 'request_ip_city:"' + data.id + '"';
                link = '#/stats/logs?' + $.param(params);
              } else {
                params.region = data.id;
                link = '#/stats/map?' + $.param(params);
              }

              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
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

  refreshData: Ember.observer('regions', function() {
    let table = this.$().find('table').dataTable().api();
    table.clear();
    table.rows.add(this.get('regions'));
    table.draw();
  }),

  downloadUrl: Ember.computed('allQueryParamValues', function() {
    return '/admin/stats/map.csv?' + $.param(this.get('allQueryParamValues'));
  }),
});
