Admin.StatsBaseController = Ember.ObjectController.extend({
  needs: ['application'],

  query: null,

  actions: {
    submit: function() {
      if($('#filter_type_advanced').css('display') === 'none') {
        this.set('query.params.search', null);
        this.set('query.params.query', JSON.stringify($('#query_builder').queryBuilder('getRules')));
      } else {
        this.set('query.params.query', null);
        this.set('query.params.search', $('#filter_form input[name=search]').val());
      }
    },
  },
});
