Admin.AdminGroupsTableView = Ember.View.extend({
  tagName: 'table',

  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  didInsertElement: function() {
    this.$().DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/admin_groups.json',
      pageLength: 50,
      order: [[0, 'asc']],
      columns: [
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/admin_groups/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          data: 'api_scope_display_names',
          title: 'API Scopes',
          render: function(names, type) {
            if(type === 'display' && names && names !== '-') {
              return names.join('<br>');
            }

            return names;
          }
        },
        {
          data: 'permission_display_names',
          title: 'Access',
          defaultContent: '-',
          render: function(names, type) {
            if(type === 'display' && names && names !== '-') {
              return names.join('<br>');
            }

            return names;
          }
        }
      ]
    });
  },
});
