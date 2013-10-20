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
      "aaData": this.get('data'),
      "aoColumns": [
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
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
    table.fnAddData(this.get('data'));
  }.observes('data'),
});
