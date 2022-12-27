// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { reads } from '@ember/object/computed';
import { inject as service } from '@ember/service';
import { tagName } from '@ember-decorators/component';
// eslint-disable-next-line ember/no-mixins
import Sortable from 'api-umbrella-admin-ui/mixins/sortable';
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import without from 'lodash-es/without';

@classic
@tagName("")
export default class SubSettingsTable extends Component.extend(Sortable) {
  @service store;

  openModal = false;

  @reads('model.subSettings')
  sortableCollection;

  @action
  add() {
    this.set('subSettingsModel', this.store.createRecord('api/sub-settings'));
    this.set('openModal', true);
  }

  @action
  edit(subSettings) {
    this.set('subSettingsModel', subSettings);
    this.set('openModal', true);
  }

  @action
  remove(subSettings) {
    bootbox.confirm('Are you sure you want to remove this URL setting?', (response) => {
      if(response) {
        let collection = without(this.model.subSettings, subSettings);
        this.model.set('subSettings', collection);
      }
    });
  }
}
