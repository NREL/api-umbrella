import classic from 'ember-classic-decorator';
import { tagName } from '@ember-decorators/component';
import { action, computed } from '@ember/object';
import { getOwner } from '@ember/application';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import SubSettings from 'api-umbrella-admin-ui/models/api/sub-settings';
import BufferedProxy from 'ember-buffered-proxy/proxy';

// eslint-disable-next-line ember/no-classic-classes
@classic
@tagName("")
export default class SubSettingsForm extends Component {
  openModal = false;

  init() {
    super.init(...arguments);

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
      return 'Add Sub-URL Request Settings';
    } else {
      return 'Edit Sub-URL Request Settings';
    }
  }

  @computed('model')
  get bufferedModel() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(SubSettings.validationClass).create(owner, { content: this.model });
  }

  @action
  submitForm() {
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
