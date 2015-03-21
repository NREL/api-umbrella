Admin.WebsiteBackendsTableView = Ember.View.extend({
  tagName: 'table',
  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.set('table', this.$().DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/website_backends.json',
      pageLength: 50,
      rowCallback: function(row, data) {
        $(row).data('id', data.id);
      },
      order: [[0, 'asc']],
      columns: [
        {
          data: 'frontend_host',
          title: 'Host',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/website_backends/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
      ]
    }));
  },
});
