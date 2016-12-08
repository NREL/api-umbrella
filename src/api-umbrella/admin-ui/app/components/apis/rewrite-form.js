import Ember from 'ember';
import BufferedProxy from 'ember-buffered-proxy/proxy';

export default Ember.Component.extend({
  openModal: false,
  matcherTypeOptions: [
    { id: 'route', name: 'Route Pattern' },
    { id: 'regex', name: 'Regular Expression' },
  ],
  httpMethodOptions: [
    { id: 'any', name: 'Any' },
    { id: 'GET', name: 'GET' },
    { id: 'POST', name: 'POST' },
    { id: 'PUT', name: 'PUT' },
    { id: 'DELETE', name: 'DELETE' },
    { id: 'HEAD', name: 'HEAD' },
    { id: 'TRACE', name: 'TRACE' },
    { id: 'OPTIONS', name: 'OPTIONS' },
    { id: 'CONNECT', name: 'CONNECT' },
    { id: 'PATCH', name: 'PATCH' },
  ],

  modalTitle: Ember.computed('model', function() {
    if(this.get('model.isNew')) {
      return 'Add Matching URL Prefix';
    } else {
      return 'Edit Matching URL Prefix';
    }
  }),

  bufferedModel: Ember.computed('model', function() {
    return BufferedProxy.create({ content: this.get('model') });
  }),

  actions: {
    submit() {
      this.get('bufferedModel').applyChanges();
      if(this.get('model.isNew')) {
        this.get('collection').pushObject(this.get('model'));
      }

      this.set('openModal', false);
    },

    closed() {
      this.get('bufferedModel').discardChanges();
    },
  },
});
