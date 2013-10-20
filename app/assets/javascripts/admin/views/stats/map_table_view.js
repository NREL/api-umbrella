Admin.StatsMapTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().dataTable({
      "bProcessing": true,
      "bFilter": false,
      "bSearchable": false,
      "sDom": 'rt<"row-fluid"<"span3 table-info"i><"span6 table-pagination"p><"span3 table-length"l>>',
      "oLanguage": {
        "sProcessing": '<i class="icon-spinner icon-spin icon-large"></i>'
      },
      "aaSorting": [[1, "desc"]],
      "aaData": this.get('model.regions'),
      "aoColumns": [
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
          mRender: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link;
              if(this.get('model.region_field') === 'request_ip_city') {
                var params = _.clone(this.get('controller.query.params'));
                params.search = 'request_ip_city:"' + data.id + '"';
                var link = '#/stats/logs/' + $.param(params);
              } else {
                var params = _.clone(this.get('controller.query.params'));
                params.region = data.id;
                var link = '#/stats/map/' + $.param(params);
              }

              return '<a href="' + link + '">' + name + '</a>';
            }

            return name;
          }, this),
        },
        {
          mData: "hits",
          sTitle: "Hits",
          sDefaultContent: "-",
          mRender: function(number, type) {
            if(type === 'display' && number && number !== '-') {
              return numeral(number).format('0,0')
            }

            return number;
          },
        },
      ]
    });
  },

  refreshData: function() {
    var table = this.$().dataTable();
    table.fnClearTable();
    table.fnAddData(this.get('model.regions'));
  }.observes('model.regions'),
});
