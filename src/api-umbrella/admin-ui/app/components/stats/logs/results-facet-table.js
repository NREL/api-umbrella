// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
// eslint-disable-next-line ember/no-observers
import { observer } from '@ember/object';
import { on } from '@ember/object/evented';
import $ from 'jquery';
import clone from 'lodash-es/clone';
import compact from 'lodash-es/compact';
import each from 'lodash-es/each';

// eslint-disable-next-line ember/no-classic-classes
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
