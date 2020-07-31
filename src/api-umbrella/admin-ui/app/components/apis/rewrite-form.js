import BufferedProxy from 'ember-buffered-proxy/proxy';
import Component from '@ember/component';
import Rewrite from 'api-umbrella-admin-ui/models/api/rewrite';
import { computed } from '@ember/object';
import { getOwner } from '@ember/application';

export default Component.extend({
  openModal: false,

  init() {
    this._super(...arguments);

    this.matcherTypeOptions = [
      { id: 'route', name: 'Route Pattern' },
      { id: 'regex', name: 'Regular Expression' },
    ];

    this.httpMethodOptions = [
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
    ];
  },

  modalTitle: computed('model.isNew', function() {
    if(this.model.isNew) {
      return 'Add Matching URL Prefix';
    } else {
      return 'Edit Matching URL Prefix';
    }
  }),

  bufferedModel: computed('model', function() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(Rewrite.validationClass).create(owner, { content: this.model });
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
