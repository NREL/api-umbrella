import Component from '@ember/component';
import Sortable from 'api-umbrella-admin-ui/mixins/sortable';
import bootbox from 'bootbox';
import { computed } from '@ember/object';
import { inject } from '@ember/service';

export default Component.extend(Sortable, {
  store: inject(),
  openModal: false,

  sortableCollection: computed.reads('model.urlMatches'),

  actions: {
    add() {
      this.set('urlMatchModel', this.store.createRecord('api/url-match'));
      this.set('openModal', true);
    },

    edit(urlMatch) {
      this.set('urlMatchModel', urlMatch);
      this.set('openModal', true);
    },

    remove(urlMatch) {
      bootbox.confirm('Are you sure you want to remove this URL prefix?', function(response) {
        if(response) {
          this.model.urlMatches.removeObject(urlMatch);
        }
      }.bind(this));
    },
  },
});
