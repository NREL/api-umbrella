import Component from '@ember/component';
import bootbox from 'bootbox';
import { inject } from '@ember/service';

export default Component.extend({
  store: inject(),
  openModal: false,

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
          this.get('model.subSettings').removeObject(subSettings);
        }
      }.bind(this));
    },
  },

});
