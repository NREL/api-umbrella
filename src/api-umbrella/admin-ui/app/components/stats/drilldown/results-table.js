// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import { inject } from '@ember/service';
import { observes } from '@ember-decorators/object';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import clone from 'lodash-es/clone';
import escape from 'lodash-es/escape';
import numeral from 'numeral';

// eslint-disable-next-line ember/no-classic-classes
@classic
export default class ResultsTable extends Component {
  @inject()
  session;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.$().find('table').DataTable({
      searching: false,
      order: [[1, 'desc']],
      data: this.results,
      columns: [
        {
          data: 'path',
          title: 'Path',
          defaultContent: '-',
          render: function(name, type, data) {
            if(type === 'display' && name && name !== '-') {
              if(data.terminal) {
                return '<i class="far fa-file fa-fw mr-1"></i>' + escape(name);
              } else {
                let params = clone(this.presentQueryParamValues);
                params.prefix = data.descendent_prefix;
                let link = '#/stats/drilldown?' + $.param(params);

                return '<a href="' + link + '"><i class="far fa-folder fa-fw mr-1"></i>' + escape(name) + '</a>';
              }
            }

            return name;
          }.bind(this),
        },
        {
          data: 'hits',
          title: 'Hits',
          defaultContent: '-',
          render(number, type) {
            if(type === 'display' && number && number !== '-') {
              return numeral(number).format('0,0');
            }

            return number;
          },
        },
      ],
    });
  }

  // eslint-disable-next-line ember/no-observers
  @observes('results')
  refreshData() {
    let table = this.$().find('table').dataTable().api();
    table.clear();
    table.rows.add(this.results);
    table.draw();
  }

  @computed('backendQueryParamValues', 'session.data.authenticated.api_key')
  get downloadUrl() {
    return '/api-umbrella/v1/analytics/drilldown.csv?api_key=' + this.session.data.authenticated.api_key + '&' + $.param(this.backendQueryParamValues);
  }
}
