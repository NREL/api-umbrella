Admin.ApplicationRoute = Ember.Route.extend({
  actions: {
    openModal: function(template) {
      this.render(template, { into: "modal", outlet: "modalBody" });
      $(".modal").modal("show");
    },

    closeModal: function() {
      this.render("hide_modal", { into: "modal", outlet: "modalBody" });
    },
  },
});
