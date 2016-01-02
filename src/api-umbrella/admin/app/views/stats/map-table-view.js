Admin.StatsMapTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      searching: false,
      order: [[1, 'desc']],
      data: this.get('model.regions'),
      columns: [
        {
          data: 'name',
          title: 'Location',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link, params;
              if(this.get('model.region_field') === 'request_ip_city') {
                params = _.clone(this.get('controller.query.params'));
                params.search = 'request_ip_city:"' + data.id + '"';
                link = '#/stats/logs/' + $.param(params);
              } else {
                params = _.clone(this.get('controller.query.params'));
                params.region = data.id;
                link = '#/stats/map/' + $.param(params);
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
          render: function(number, type) {
            if(type === 'display' && number && number !== '-') {
              return numeral(number).format('0,0');
            }

            return number;
          },
        },
      ]
    });
  },

  refreshData: function() {
    var table = this.$().DataTable();
    table.clear();
    table.rows.add(this.get('model.regions')).draw();
  }.observes('model.regions'),
});
