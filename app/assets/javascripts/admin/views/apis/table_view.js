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
    this.set('table', this.$().dataTable({
      "bServerSide": true,
      "sAjaxSource": "/admin/apis.json",
      "iDisplayLength": 50,
      "fnRowCallback": function(row, data) {
        $(row).data("id", data.id);
        $(row).data("sort-order", data.sort_order);
      },
      "aaSorting": [[0, "asc"]],
      "aoColumns": [
        {
          mData: "name",
          sTitle: "Name",
          sDefaultContent: "-",
          mRender: _.bind(function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              var link = '#/apis/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          mData: "frontend_host",
          sTitle: "Host",
          sDefaultContent: "-",
        },
        {
          mData: "frontend_prefixes",
          sTitle: "Prefixes",
          sDefaultContent: "-",
        },
        {
          mData: "sort_order",
          sTitle: "Matching Order",
          sDefaultContent: "-",
          sWidth: 130,
        },
        {
          mData: null,
          sClass: "reorder-handle",
          bSortable: false,
          mRender: function() {
            return '<i class="icon-reorder"></i>';
          },
        },
      ]
    }));

    this.get('table')
      .on('filter', _.bind(function(event, settings) {
        // Disable reordering if the user tries to filter the table by anything
        // (otherwise, our reordering logic won't work, since it relies on the
        // neighboring rows).
        if(this.get('controller.reorderActive')) {
          if(settings.oPreviousSearch && settings.oPreviousSearch.sSearch) {
            this.set('controller.reorderActive', false);
          }
        }
      }, this))
      .on('sort', _.bind(function(event, settings) {
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
        var currentOrder = parseInt(row.data('sort-order'));
        var previousRow = row.prev('tbody tr');
        var moveTo = 1;
        if(previousRow.length > 0) {
          moveTo = parseInt($(previousRow[0]).data('sort-order'));
          if(moveTo < currentOrder) {
            moveTo++;
          }
        } else {
          var data = this.get('table').fnGetData();
          var sortOrders = _.map(_.compact(_.pluck(data, 'sort_order')), function(order) { return parseInt(order) });
          var minSortOrder = sortOrders.sort()[0];
          if(minSortOrder && minSortOrder > 1) {
            moveTo = minSortOrder - 1;
          }
        }

        this.saveReorder(row.data('id'), moveTo);
      }, this),
    });
  },

  handleReorderChange: function() {
    if(this.get('controller.reorderActive')) {
      this.$().addClass('reorder-active');
      this.get('table').fnSort([[3, 'asc']]);
      this.get('table').fnFilter('');
    } else {
      this.$().removeClass('reorder-active');
    }
  }.observes('controller.reorderActive'),

  saveReorder: function(id, moveTo) {
    this.get('table').fnProcessingIndicator(true);
    $.ajax({
      url: '/admin/apis/' + id + '/move_to.json',
      type: 'PUT',
      data: { move_to: moveTo },
    }).done(_.bind(function() {
      this.get('table').fnDraw();
    }, this)).fail(_.bind(function() {
      bootbox.alert('An unexpected error occurred. Please try again.');
      this.get('table').fnDraw();
    }, this));
  },
});
