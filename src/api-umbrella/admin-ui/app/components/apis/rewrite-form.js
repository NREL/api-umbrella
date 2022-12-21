import { getOwner } from '@ember/application';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import { tracked } from '@glimmer/tracking';
import Rewrite from 'api-umbrella-admin-ui/models/api/rewrite';
import BufferedProxy from 'ember-buffered-proxy/proxy';
import classic from 'ember-classic-decorator';

@classic
@tagName("")
export default class RewriteForm extends Component {
  openModal = false;

  init() {
    super.init(...arguments);

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
  }

  @computed('model.isNew')
  get modalTitle() {
    if(this.model.isNew) {
      return 'Add Matching URL Prefix';
    } else {
      return 'Edit Matching URL Prefix';
    }
  }

  @computed('model')
  get bufferedModel() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(Rewrite.validationClass).create(owner, { content: this.model });
  }

  @action
  submitForm(event) {
    event.preventDefault();
    this.bufferedModel.applyChanges();
    if(this.model.isNew) {
      this.collection.pushObject(this.model);
    }

    this.set('openModal', false);
  }

  @action
  closed() {
    this.bufferedModel.discardChanges();
    this.set('openModal', false);
  }
}
