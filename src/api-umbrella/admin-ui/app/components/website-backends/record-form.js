// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import { observes } from '@ember-decorators/object';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import classic from 'ember-classic-decorator';
import escape from 'lodash-es/escape';

@classic
@tagName("")
export default class RecordForm extends Component.extend(Save) {
  init() {
    super.init(...arguments);

    this.backendProtocolOptions = [
      { id: 'http', name: 'http' },
      { id: 'https', name: 'https' },
    ];
  }

  // eslint-disable-next-line ember/no-observers
  @observes('model.backendProtocol')
  changeDefaultPort() {
    let protocol = this.model.backendProtocol;
    let port = parseInt(this.model.serverPort, 10);
    if(protocol === 'https') {
      if(!port || port === 80) {
        this.set('model.serverPort', 443);
      }
    } else {
      if(!port || port === 443) {
        this.set('model.serverPort', 80);
      }
    }
  }

  @action
  submitForm(event) {
    event.preventDefault();
    this.saveRecord({
      element: event.target,
      transitionToRoute: 'website_backends',
      message: 'Successfully saved the "' + escape(this.model.frontendHost) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
    });
  }

  @action
  delete() {
    this.destroyRecord({
      prompt: 'Are you sure you want to delete the website backend "' + escape(this.model.frontendHost) + '"?',
      transitionToRoute: 'website_backends',
      message: 'Successfully deleted the "' + escape(this.model.frontendHost) + '" website backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
    });
  }
}
