// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { observes, on } from '@ember-decorators/object';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import clone from 'lodash-es/clone';
import compact from 'lodash-es/compact';
import each from 'lodash-es/each';

@classic
export default class ResultsFacetTable extends Component {
  // eslint-disable-next-line ember/require-tagless-components
  tagName = 'div';

  @on('init')
  // eslint-disable-next-line ember/no-observers
  @observes('facets')
  setLinks() {
    each(this.facets, (bucket) => {
      let params = clone(this.presentQueryParamValues);
      params.search = compact([params.search, this.field + ':"' + bucket.key + '"']).join(' AND ');
      bucket.link = '#/stats/logs?' + $.param(params);
    });
  }

  @action
  toggleFacetTable() {
    $(this.element).find('table').toggle();
  }
}
