import BufferedProxy from 'ember-buffered-proxy/proxy';
import Component from '@ember/component';
import UrlMatch from 'api-umbrella-admin-ui/models/api/url-match';
import { computed } from '@ember/object';
import { getOwner } from '@ember/application';

export default Component.extend({
  openModal: false,
  exampleSuffix: 'example.json?param=value',

  modalTitle: computed('model.isNew', function() {
    if(this.model.isNew) {
      return 'Add Matching URL Prefix';
    } else {
      return 'Edit Matching URL Prefix';
    }
  }),

  bufferedModel: computed('model', function() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(UrlMatch.validationClass).create(owner, { content: this.model });
  }),

  exampleIncomingUrl: computed('apiExampleIncomingUrlRoot', 'bufferedModel.frontendPrefix', 'exampleSuffix', function() {
    let root = this.apiExampleIncomingUrlRoot || '';
    let prefix = this.bufferedModel.get('frontendPrefix') || '';
    return root + prefix + this.exampleSuffix;
  }),

  exampleOutgoingUrl: computed('apiExampleOutgoingUrlRoot', 'bufferedModel.{backendPrefix,frontendPrefix}', 'exampleSuffix', function() {
    let root = this.apiExampleOutgoingUrlRoot || '';
    let prefix = this.bufferedModel.get('backendPrefix') || this.bufferedModel.get('frontendPrefix') || '';
    return root + prefix + this.exampleSuffix;
  }),

  actions: {
    submit() {
      this.bufferedModel.applyChanges();
      if(this.model.isNew) {
        this.collection.pushObject(this.model);
      }

      this.set('openModal', false);
    },

    closed() {
      this.bufferedModel.discardChanges();
      this.set('openModal', false);
    },
  },
});
