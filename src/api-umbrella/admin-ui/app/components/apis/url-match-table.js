// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { inject as service } from '@ember/service';
import { tagName } from '@ember-decorators/component';
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import without from 'lodash-es/without';

@classic
@tagName("")
export default class UrlMatchTable extends Component {
  @service store;

  openModal = false;

  @action
  add() {
    this.set('urlMatchModel', this.store.createRecord('api/url-match'));
    this.set('openModal', true);
  }

  @action
  edit(urlMatch) {
    this.set('urlMatchModel', urlMatch);
    this.set('openModal', true);
  }

  @action
  remove(urlMatch) {
    bootbox.confirm('Are you sure you want to remove this URL prefix?', (response) => {
      if(response) {
        let collection = without(this.model.urlMatches, urlMatch);
        this.model.set('urlMatches', collection);
      }
    });
  }
}
