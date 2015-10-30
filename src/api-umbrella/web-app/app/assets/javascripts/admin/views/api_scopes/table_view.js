Admin.ApiScopesTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/api_scopes.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/api_scopes/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          data: 'host',
          title: 'Host',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'path_prefix',
          title: 'Path Prefix',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        }
      ]
    });
  },
});
