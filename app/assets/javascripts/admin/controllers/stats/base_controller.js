Admin.StatsBaseController = Ember.ObjectController.extend({
  needs: ['application'],

  query: null,

  actions: {
    submit: function() {
      this.set('query.params.search', $('#filter_form input[name=search]').val());
    },
  },
});
