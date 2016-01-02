Admin.StatsFacetTableView = Ember.View.extend({
  templateName: 'stats/_facet_table',

  setLinks: function() {
    _.each(this.data, _.bind(function(bucket) {
      var params = _.clone(this.get('controller.query.params'));
      params.search = _.compact([params.search, this.facetTerm + ':"' + bucket.key + '"']).join(' AND ');
      bucket.linkQuery = $.param(params);
    }, this));
  }.observes('data').on('init'),

  actions: {
    toggleFacetTable: function() {
      this.$().find('table').toggle();
    },
  },
});
