Admin.ApisTableView = Ember.View.extend({
  tagName: 'table',
  classNames: ['table', 'table-striped', 'table-bordered', 'table-condensed'],

  init: function() {
    this._super();

    // We're observing the controller, which is a computed property on views.
    // Force fetching it so the observers fire:
    // http://emberjs.com/guides/object-model/observers/#toc_unconsumed-computed-properties-do-not-trigger-observers
    this.get('controller');
  },

  didInsertElement: function() {
    this.set('table', this.$().DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/apis.json',
      pageLength: 50,
      rowCallback: function(row, data) {
        $(row).data('id', data.id);
      },
      order: [[0, 'asc']],
      columns: [
        {
          data: 'name',
          title: 'Name',
          defaultContent: '-',
          render: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/apis/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          data: 'frontend_host',
          title: 'Host',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'frontend_prefixes',
          title: 'Prefixes',
          defaultContent: '-',
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: 'sort_order',
          title: 'Matching Order',
          defaultContent: '-',
          width: 130,
          render: Admin.DataTablesHelpers.renderEscaped,
        },
        {
          data: null,
          className: 'reorder-handle',
          orderable: false,
          render: function() {
            return '<i class="fa fa-reorder"></i>';
          },
        },
      ]
    }));

    this.get('table')
      .on('search', _.bind(function(event, settings) {
        // Disable reordering if the user tries to filter the table by anything
        // (otherwise, our reordering logic won't work, since it relies on the
        // neighboring rows).
        if(this.get('controller.reorderActive')) {
          if(settings.oPreviousSearch && settings.oPreviousSearch.sSearch) {
            this.set('controller.reorderActive', false);
          }
        }
      }, this))
      .on('order', _.bind(function(event, settings) {
        // Disable reordering if the user tries to sort the table by anything
        // other than the sort order (otherwise, our reordering logic won't
        // work, since it relies on the neighboring rows).
        if(this.get('controller.reorderActive')) {
          if(settings.aaSorting && !_.isEqual(settings.aaSorting, [[3, 'asc']])) {
            this.set('controller.reorderActive', false);
          }
        }
      }, this));

    this.$().find('tbody').sortable({
      handle: '.reorder-handle',
      placeholder: 'reorder-placeholder',
      helper: function(event, ui) {
        ui.children().each(function() {
          $(this).width($(this).width());
        });
        return ui;
      },
      stop: _.bind(function(event, ui) {
        var row = $(ui.item);
        var previousRow = row.prev('tbody tr');
        var moveAfterId = null;
        if(previousRow.length > 0) {
          moveAfterId = $(previousRow[0]).data('id');
        }

        this.saveReorder(row.data('id'), moveAfterId);
      }, this),
    });
  },

  handleReorderChange: function() {
    if(this.get('controller.reorderActive')) {
      this.$().addClass('reorder-active');
      this.get('table')
        .order([[3, 'asc']])
        .search('')
        .draw();
    } else {
      this.$().removeClass('reorder-active');
    }
  }.observes('controller.reorderActive'),

  saveReorder: function(id, moveAfterId) {
    this.$().dataTable().fnProcessingIndicator(true);
    $.ajax({
      url: '/api-umbrella/v1/apis/' + id + '/move_after.json',
      type: 'PUT',
      data: { move_after_id: moveAfterId },
    }).done(_.bind(function() {
      this.get('table').draw();
    }, this)).fail(_.bind(function() {
      bootbox.alert('An unexpected error occurred. Please try again.');
      this.get('table').draw();
    }, this));
  },
});
