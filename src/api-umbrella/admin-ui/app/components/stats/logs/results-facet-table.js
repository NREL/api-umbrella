import Ember from 'ember';

export default Ember.Component.extend({
  setLinks: Ember.on('init', Ember.observer('facets', function() {
    _.each(this.get('facets'), function(bucket) {
      let params = _.clone(this.get('presentQueryParamValues'));
      params.search = _.compact([params.search, this.get('field') + ':"' + bucket.key + '"']).join(' AND ');
      bucket.link = '#/stats/logs?' + $.param(params);
    }.bind(this));
  })),

  actions: {
    toggleFacetTable() {
      this.$().find('table').toggle();
    },
  },
});
