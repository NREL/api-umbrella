import Ember from 'ember';
import BufferedProxy from 'ember-buffered-proxy/proxy';

export default Ember.Component.extend({
  openModal: false,
  exampleSuffix: 'example.json?param=value',

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

  exampleIncomingUrl: Ember.computed('bufferedModel.frontendPrefix', function() {
    let root = this.get('apiExampleIncomingUrlRoot') || '';
    let prefix = this.get('bufferedModel.frontendPrefix') || '';
    return root + prefix + this.get('exampleSuffix');
  }),

  exampleOutgoingUrl: Ember.computed('bufferedModel.frontendPrefix', 'bufferedModel.backendPrefix', function() {
    let root = this.get('apiExampleIncomingUrlRoot') || '';
    let prefix = this.get('bufferedModel.backendPrefix') || this.get('bufferedModel.frontendPrefix') || '';
    return root + prefix + this.get('exampleSuffix');
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
