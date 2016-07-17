import Ember from 'ember';
import Sortable from 'api-umbrella-admin/mixins/sortable';

export default Ember.Component.extend(Sortable, {
  store: Ember.inject.service(),
  openModal: false,

  sortableCollection: Ember.computed('model', function() {
    return this.get('model.subSettings');
  }),

  actions: {
    add() {
      this.set('subSettingsModel', this.get('store').createRecord('api/sub-settings'));
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
