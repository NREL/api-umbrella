import Component from '@ember/component';
import Sortable from 'api-umbrella-admin-ui/mixins/sortable';
import bootbox from 'bootbox';
import { computed } from '@ember/object';
import { inject } from '@ember/service';

export default Component.extend(Sortable, {
  store: inject(),
  openModal: false,

  sortableCollection: computed.reads('model.rewrites'),

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
          this.model.rewrites.removeObject(rewrite);
        }
      }.bind(this));
    },
  },
});
