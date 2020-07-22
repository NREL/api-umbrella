import Component from '@ember/component';
import bootbox from 'bootbox';
import { inject } from '@ember/service';

export default Component.extend({
  store: inject(),
  openModal: false,

  actions: {
    add() {
      this.set('rewriteModel', this.store.createRecord('api/rewrite'));
      this.set('openModal', true);
    },

    edit(rewrite) {
      this.set('rewriteModel', rewrite);
      this.set('openModal', true);
    },

    remove(rewrite) {
      bootbox.confirm('Are you sure you want to remove this rewrite?', function(response) {
        if(response) {
          this.get('model.rewrites').removeObject(rewrite);
        }
      }.bind(this));
    },
  },
});
