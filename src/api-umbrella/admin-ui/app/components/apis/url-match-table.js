import Ember from 'ember';
import Sortable from 'api-umbrella-admin/mixins/sortable';

export default Ember.Component.extend(Sortable, {
  store: Ember.inject.service(),
  openModal: false,

  sortableCollection: Ember.computed('model', function() {
    return this.get('model.urlMatches');
  }),

  actions: {
    add() {
      this.set('urlMatchModel', this.get('store').createRecord('api/url-match'));
      this.set('openModal', true);
    },

    edit(urlMatch) {
      this.set('urlMatchModel', urlMatch);
      this.set('openModal', true);
    },

    remove(urlMatch) {
      bootbox.confirm('Are you sure you want to remove this URL prefix?', function(response) {
        if(response) {
          this.get('model.urlMatches').removeObject(urlMatch);
        }
      }.bind(this));
    },
  },
});
