import Ember from 'ember';
import Sortable from 'api-umbrella-admin/mixins/sortable';

export default Ember.Component.extend(Sortable, {
  store: Ember.inject.service(),
  openModal: false,

  sortableCollection: Ember.computed('model', function() {
    return this.get('model.rewrites');
  }),

  actions: {
    add() {
      this.set('rewriteModel', this.get('store').createRecord('api/rewrite'));
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
