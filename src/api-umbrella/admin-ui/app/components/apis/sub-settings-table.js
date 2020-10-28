import Component from '@ember/component';
// eslint-disable-next-line ember/no-mixins
import Sortable from 'api-umbrella-admin-ui/mixins/sortable';
import bootbox from 'bootbox';
import { computed } from '@ember/object';
import { inject } from '@ember/service';

export default Component.extend(Sortable, {
  store: inject(),
  openModal: false,

  sortableCollection: computed.reads('model.subSettings'),

  actions: {
    add() {
      this.set('subSettingsModel', this.store.createRecord('api/sub-settings'));
      this.set('openModal', true);
    },

    edit(subSettings) {
      this.set('subSettingsModel', subSettings);
      this.set('openModal', true);
    },

    remove(subSettings) {
      bootbox.confirm('Are you sure you want to remove this URL setting?', function(response) {
        if(response) {
          this.model.subSettings.removeObject(subSettings);
        }
      }.bind(this));
    },
  },

});
