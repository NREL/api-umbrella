Admin.ApplicationRoute = Ember.Route.extend({
  actions: {
    openModal: function(template) {
      this.render(template, { into: 'modal', outlet: 'modalBody' });
      $('.modal').modal({
        // Don't close when the background is clicked or the escape key is hit.
        // Not quite ideal, but this ensures the user hits either the "Cancel"
        // or "OK" button for the modal forms so we can properly react. If we
        // change this we need to determine how to listen for closes via
        // keyboard or background clicks and what the behavior should be
        // (cancel, or ok?).
        backdrop: 'static',
        keyboard: false
      });
    },

    closeModal: function() {
      this.render('hide_modal', { into: 'modal', outlet: 'modalBody' });
    },
  },
});
