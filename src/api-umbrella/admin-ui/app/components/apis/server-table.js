import Component from '@ember/component';
import { inject } from '@ember/service';

export default Component.extend({
  store: inject(),
  openModal: false,

  actions: {
    add() {
      this.set('serverModel', this.get('store').createRecord('api/server'));
      this.set('openModal', true);
    },

    edit(server) {
      this.set('serverModel', server);
      this.set('openModal', true);
    },

    remove(server) {
      bootbox.confirm('Are you sure you want to remove this server?', function(response) {
        if(response) {
          this.get('model.servers').removeObject(server);
        }
      }.bind(this));
    },
  },
});
