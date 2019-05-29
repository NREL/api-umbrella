import $ from 'jquery';
import Component from '@ember/component';
import clone from 'lodash-es/clone';
import compact from 'lodash-es/compact';
import each from 'lodash-es/each';
import { observer } from '@ember/object';
import { on } from '@ember/object/evented';

export default Component.extend({
  // eslint-disable-next-line ember/no-on-calls-in-components, ember/no-observers
  setLinks: on('init', observer('facets', function() {
    each(this.facets, function(bucket) {
      let params = clone(this.presentQueryParamValues);
      params.search = compact([params.search, this.field + ':"' + bucket.key + '"']).join(' AND ');
      bucket.link = '#/stats/logs?' + $.param(params);
    }.bind(this));
  })),

  actions: {
    toggleFacetTable() {
      this.$().find('table').toggle();
    },
  },
});
