import 'jquery-ui/ui/widgets/sortable';
import $ from 'jquery';
import Component from '@ember/component';
import DataTablesHelpers from 'api-umbrella-admin-ui/utils/data-tables-helpers';
import bootbox from 'bootbox';
import escape from 'lodash-es/escape';
import { inject } from '@ember/service';
import isEqual from 'lodash-es/isEqual';
import { observer } from '@ember/object';

export default Component.extend({
  busy: inject('busy'),
  session: inject('session'),
  reorderActive: false,

  didInsertElement() {
    const currentAdmin = this.get('session.data.authenticated.admin');

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
          render: (name, type, data) => {
            if(type === 'display' && name && name !== '-') {
              let link = '#/apis/' + data.id + '/edit';
              return '<a href="' + link + '">' + escape(name) + '</a>';
            }

            return name;
          },
        },
        {
          data: 'frontend_host',
          title: 'Host',
          defaultContent: '-',
          render: DataTablesHelpers.renderEscaped,
        },
        {
          data: 'url_matches',
          title: 'Prefixes',
          defaultContent: '-',
          orderable: false,
          render: DataTablesHelpers.renderList({
            nameField: 'frontend_prefix',
          }),
        },
        ...(currentAdmin.superuser ? [
          {
            data: 'root_api_scope.name',
            title: 'Root API Scope',
            defaultContent: '-',
            render: DataTablesHelpers.renderLink({
              editLink: '#/api_scopes/',
              idField: 'root_api_scope.id',
            }),
          },
          {
            data: 'api_scopes',
            title: 'API Scopes',
            defaultContent: '-',
            orderable: false,
            render: DataTablesHelpers.renderLinkedList({
              editLink: '#/api_scopes/',
              nameField: 'name',
            }),
          },
          {
            data: 'admin_groups',
            title: 'Admin Groups',
            defaultContent: '-',
            orderable: false,
            render: DataTablesHelpers.renderLinkedList({
              editLink: '#/admin_groups/',
              nameField: 'name',
            }),
          },
        ] : []),
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
            return '<i class="fas fa-bars"></i>';
          },
        },
      ],
    }));

    this.table
      .on('search', (event, settings) => {
        // Disable reordering if the user tries to filter the table by anything
        // (otherwise, our reordering logic won't work, since it relies on the
        // neighboring rows).
        if(this.reorderActive) {
          if(settings.oPreviousSearch && settings.oPreviousSearch.sSearch) {
            this.set('reorderActive', false);
          }
        }
      })
      .on('order', (event, settings) => {
        // Disable reordering if the user tries to sort the table by anything
        // other than the sort order (otherwise, our reordering logic won't
        // work, since it relies on the neighboring rows).
        if(this.reorderActive) {
          if(settings.aaSorting && !isEqual(settings.aaSorting, [[3, 'asc']])) {
            this.set('reorderActive', false);
          }
        }
      });

    this.$().find('tbody').sortable({
      handle: '.reorder-handle',
      placeholder: 'reorder-placeholder',
      helper(event, ui) {
        ui.children().each(function() {
          $(this).width($(this).width());
        });
        return ui;
      },
      stop: (event, ui) => {
        let row = $(ui.item);
        let previousRow = row.prev('tbody tr');
        let moveAfterId = null;
        if(previousRow.length > 0) {
          moveAfterId = $(previousRow[0]).data('id');
        }

        this.saveReorder(row.data('id'), moveAfterId);
      },
    });
  },

  handleReorderChange: observer('reorderActive', function() {
    if(this.reorderActive) {
      this.$().find('table').addClass('reorder-active');
      this.table
        .order([[3, 'asc']])
        .search('')
        .draw();
    } else {
      this.$().find('table').removeClass('reorder-active');
    }

    let $container = this.$();
    if($container) {
      let $buttonText = this.$().find('.reorder-button-text');
      if(this.reorderActive) {
        $buttonText.data('originalText',  $buttonText.text());
        $buttonText.text('Done');
      } else {
        $buttonText.text($buttonText.data('originalText'));
      }
    }
  }),

  saveReorder(id, moveAfterId) {
    this.busy.show();
    $.ajax({
      url: '/api-umbrella/v1/apis/' + id + '/move_after.json',
      method: 'PUT',
      data: { move_after_id: moveAfterId },
    }).done(() => {
      // eslint-disable-next-line ember/jquery-ember-run
      this.table.draw();
    }).fail((xhr) => {
      // eslint-disable-next-line no-console
      console.error('Unexpected error: ' + xhr.status + ' ' + xhr.statusText + ' (' + xhr.readyState + '): ' + xhr.responseText);
      bootbox.alert('An unexpected error occurred. Please try again.');
      this.table.draw();
    });
  },

  actions: {
    toggleReorderApis() {
      this.set('reorderActive', !this.reorderActive);
    },
  },
});
