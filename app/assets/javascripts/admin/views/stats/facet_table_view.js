Admin.StatsFacetTableView = Ember.View.extend({
  templateName: 'stats/_facet_table',

  setLinks: function() {
    _.each(this.data, _.bind(function(term) {
      var params = _.clone(this.get('controller.query.params'));
      params.search = _.compact([params.search, this.facetTerm + ':"' + term.term + '"']).join(' AND ');
      term.linkQuery = $.param(params);
    }, this));
  }.observes('data').on('init'),

  actions: {
    toggleFacetTable: function(event) {
      this.$().find('table').toggle();
    },
  },
});
