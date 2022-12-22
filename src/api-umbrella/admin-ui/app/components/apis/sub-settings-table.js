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
    bootbox.confirm('Are you sure you want to remove this URL setting?', function(response) {
      if(response) {
        this.model.subSettings.removeObject(subSettings);
      }
    }.bind(this));
  }
}
