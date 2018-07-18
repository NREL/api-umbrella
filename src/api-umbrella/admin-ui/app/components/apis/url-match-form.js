import BufferedProxy from 'ember-buffered-proxy/proxy';
import Component from '@ember/component';
import UrlMatch from 'api-umbrella-admin-ui/models/api/url-match';
import { computed } from '@ember/object';
import { getOwner } from '@ember/application';

export default Component.extend({
  openModal: false,
  exampleSuffix: 'example.json?param=value',

  modalTitle: computed('model', function() {
    if(this.get('model.isNew')) {
      return 'Add Matching URL Prefix';
    } else {
      return 'Edit Matching URL Prefix';
    }
  }),

  bufferedModel: computed('model', function() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(UrlMatch.validationClass).create(owner, { content: this.get('model') });
  }),

  exampleIncomingUrl: computed('bufferedModel.frontendPrefix', function() {
    let root = this.get('apiExampleIncomingUrlRoot') || '';
    let prefix = this.get('bufferedModel.frontendPrefix') || '';
    return root + prefix + this.get('exampleSuffix');
  }),

  exampleOutgoingUrl: computed('bufferedModel.{frontendPrefix,backendPrefix}', function() {
    let root = this.get('apiExampleOutgoingUrlRoot') || '';
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
      this.set('openModal', false);
    },
  },
});
