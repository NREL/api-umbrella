import $ from 'jquery';

export function initialize(appInstance) {
  // Defaults for DataTables.
  _.merge($.fn.DataTable.defaults, {
    // Don't show the DataTables processing message. We'll handle the processing
    // message logic in preDrawCallback.
    processing: false,

    // Enable global searching.
    searching: true,

    // Re-arrange how the table and surrounding fields (pagination, search, etc)
    // are laid out.
    dom: 'rft<"row"<"col-sm-3 table-info"i><"col-sm-6 table-pagination"p><"col-sm-3 table-length"l>>',

    language: {
      // Don't have an explicit label for the search field. Use a placeholder
      // instead.
      search: '',
      searchPlaceholder: 'Search...',
    },

    preDrawCallback() {
      if(!this.customProcessingCallbackSet) {
        // Use a custom spinner to provide a more obvious processing message
        // the overlays the entire table (this helps for long tables, where a
        // simple processing message might appear out of your current view).
        // This also standardizes the spinner with other loaders used
        // throughout the Ember app.
        //
        // Set this early on during pre-draw so that the processing message shows
        // up for the first load.
        $(this).DataTable().on('processing', _.bind(function(event, settings, processing) {
          if(processing) {
            appInstance.lookup('service:busy').show();
          } else {
            appInstance.lookup('service:busy').hide();
          }
        }, this));

        this.customProcessingCallbackSet = true;
      }
    },
  });
}

export default {
  name: 'datatables',
  initialize,
};
