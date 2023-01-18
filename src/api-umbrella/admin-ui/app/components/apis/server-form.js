import { getOwner } from '@ember/application';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import Server from 'api-umbrella-admin-ui/models/api/server';
import BufferedProxy from 'ember-buffered-proxy/proxy';
import classic from 'ember-classic-decorator';

@classic
@tagName("")
export default class ServerForm extends Component {
  openModal = false;

  @computed('model.isNew')
  get modalTitle() {
    if(this.model.isNew) {
      return 'Add Server';
    } else {
      return 'Edit Server';
    }
  }

  @computed('model')
  get bufferedModel() {
    let owner = getOwner(this).ownerInjection();
    return BufferedProxy.extend(Server.validationClass).create(owner, { content: this.model });
  }

  @action
  open() {
    // For new servers, intelligently pick the default port based on the
    // backend protocol selected.
    if(this.bufferedModel && !this.bufferedModel.get('port')) {
      if(this.apiBackendProtocol === 'https') {
        this.set('bufferedModel.port', 443);
      } else {
        this.set('bufferedModel.port', 80);
      }
    }
  }

  @action
  submitForm(event) {
    event.preventDefault();
    this.bufferedModel.applyChanges();
    if(this.model.isNew) {
      this.collection.push(this.model);
    }

    // After the first server is added, fill out a default value for the
    // "Backend Host" field based on the server's host (because in most
    // non-load balancing situations they will match).
    if(!this.apiBackendHost) {
      let server = this.collection[0];
      if(server && server.get('host')) {
        this.set('apiBackendHost', server.get('host'));
      }
    }

    this.set('openModal', false);
  }

  @action
  closed() {
    this.bufferedModel.discardChanges();
    this.set('openModal', false);
  }
}
