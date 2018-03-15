import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import { inject } from '@ember/service';
import { observer } from '@ember/object';

export default Component.extend({
  busy: inject('busy'),
  reorderActive: false,

  didInsertElement() {
    this.set('table', this.$().find('table').DataTable({
      serverSide: true,
      ajax: '/api-umbrella/v1/apis.json',
      pageLength: 50,
      rowCallback(row, data) {
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
              let link = '#/apis/' + data.id + '/edit';
              return '<a href="' + link + '">' + _.escape(name) + '</a>';
            }

            return name;
          }, this),
        },
        {
          data: 'frontend_host',
          title: 'Host',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'frontend_prefixes',
          title: 'Prefixes',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'sort_order',
          title: 'Matching Order',
          defaultContent: '-',
          width: 130,
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: null,
          className: 'reorder-handle',
          orderable: false,
          render() {
            return '<i class="fa fa-reorder"></i>';
          },
        },
      ],
    }));

    this.get('table')
      .on('search', _.bind(function(event, settings) {
        // Disable reordering if the user tries to filter the table by anything
        // (otherwise, our reordering logic won't work, since it relies on the
        // neighboring rows).
        if(this.get('reorderActive')) {
          if(settings.oPreviousSearch && settings.oPreviousSearch.sSearch) {
            this.set('reorderActive', false);
          }
        }
      }, this))
      .on('order', _.bind(function(event, settings) {
        // Disable reordering if the user tries to sort the table by anything
        // other than the sort order (otherwise, our reordering logic won't
        // work, since it relies on the neighboring rows).
        if(this.get('reorderActive')) {
          if(settings.aaSorting && !_.isEqual(settings.aaSorting, [[3, 'asc']])) {
            this.set('reorderActive', false);
          }
        }
      }, this));

    this.$().find('tbody').sortable({
      handle: '.reorder-handle',
      placeholder: 'reorder-placeholder',
      helper(event, ui) {
        ui.children().each(function() {
          $(this).width($(this).width());
        });
        return ui;
      },
      stop: _.bind(function(event, ui) {
        let row = $(ui.item);
        let previousRow = row.prev('tbody tr');
        let moveAfterId = null;
        if(previousRow.length > 0) {
          moveAfterId = $(previousRow[0]).data('id');
        }

        this.saveReorder(row.data('id'), moveAfterId);
      }, this),
    });
  },

  handleReorderChange: observer('reorderActive', function() {
    if(this.get('reorderActive')) {
      this.$().find('table').addClass('reorder-active');
      this.get('table')
        .order([[3, 'asc']])
        .search('')
        .draw();
    } else {
      this.$().find('table').removeClass('reorder-active');
    }

    let $container = this.$();
    if($container) {
      let $buttonText = this.$().find('.reorder-button-text');
      if(this.get('reorderActive')) {
        $buttonText.data('originalText',  $buttonText.text());
        $buttonText.text('Done');
      } else {
        $buttonText.text($buttonText.data('originalText'));
      }
    }
  }),

  saveReorder(id, moveAfterId) {
    this.get('busy').show();
    $.ajax({
      url: '/api-umbrella/v1/apis/' + id + '/move_after.json',
      method: 'PUT',
      data: { move_after_id: moveAfterId },
    }).done(() => {
      // eslint-disable-next-line ember/jquery-ember-run
      this.get('table').draw();
    }).fail((xhr) => {
      // eslint-disable-next-line no-console
      console.error('Unexpected error: ' + xhr.status + ' ' + xhr.statusText + ' (' + xhr.readyState + '): ' + xhr.responseText);
      bootbox.alert('An unexpected error occurred. Please try again.');
      this.get('table').draw();
    });
  },

  actions: {
    toggleReorderApis() {
      this.set('reorderActive', !this.get('reorderActive'));
    },
  },
});
