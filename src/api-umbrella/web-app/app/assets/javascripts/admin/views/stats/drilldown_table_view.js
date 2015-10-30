Admin.StatsDrilldownTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      searching: false,
      order: [[1, 'desc']],
      data: this.get('model.results'),
      columns: [
        {
          data: 'path',
          title: 'Path',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              if(data.terminal) {
                return '<i class="fa fa-file-o fa-space-right"></i>' + _.escape(name);
              } else {
                var link, params;
                params = _.clone(this.get('controller.query.params'));
                params.prefix = data.descendent_prefix;
                link = '#/stats/drilldown/' + $.param(params);

                return '<a href="' + link + '"><i class="fa fa-folder-o fa-space-right"></i>' + _.escape(name) + '</a>';
              }
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
    table.rows.add(this.get('model.results')).draw();
  }.observes('model.results'),
});
