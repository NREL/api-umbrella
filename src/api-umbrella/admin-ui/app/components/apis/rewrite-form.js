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

  modalTitle: computed('model', function() {
    if(this.get('model.isNew')) {
      return 'Add Matching URL Prefix';
    } else {
      return 'Edit Matching URL Prefix';
    }
  }),

  bufferedModel: computed('model', function() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(Rewrite.validationClass).create(owner, { content: this.get('model') });
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
