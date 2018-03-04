import $ from 'jquery';
import Component from '@ember/component';
import { observer } from '@ember/object';
import { on } from '@ember/object/evented';

export default Component.extend({
  // eslint-disable-next-line ember/no-on-calls-in-components
  setLinks: on('init', observer('facets', function() {
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
