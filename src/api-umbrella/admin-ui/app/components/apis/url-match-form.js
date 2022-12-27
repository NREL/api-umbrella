import { getOwner } from '@ember/application';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action, computed } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import UrlMatch from 'api-umbrella-admin-ui/models/api/url-match';
import BufferedProxy from 'ember-buffered-proxy/proxy';
import classic from 'ember-classic-decorator';

@classic
@tagName("")
export default class UrlMatchForm extends Component {
  openModal = false;
  exampleSuffix = 'example.json?param=value';

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
    return BufferedProxy.extend(UrlMatch.validationClass).create(owner, { content: this.model });
  }

  @computed(
    'apiExampleIncomingUrlRoot',
    'bufferedModel.frontendPrefix',
    'exampleSuffix',
  )
  get exampleIncomingUrl() {
    let root = this.apiExampleIncomingUrlRoot || '';
    let prefix = this.bufferedModel.get('frontendPrefix') || '';
    return root + prefix + this.exampleSuffix;
  }

  @computed(
    'apiExampleOutgoingUrlRoot',
    'bufferedModel.{backendPrefix,frontendPrefix}',
    'exampleSuffix',
  )
  get exampleOutgoingUrl() {
    let root = this.apiExampleOutgoingUrlRoot || '';
    let prefix = this.bufferedModel.get('backendPrefix') || this.bufferedModel.get('frontendPrefix') || '';
    return root + prefix + this.exampleSuffix;
  }

  @action
  submitForm(event) {
    event.preventDefault();
    this.bufferedModel.applyChanges();
    if(this.model.isNew) {
      this.collection.push(this.model);
    }

    this.set('openModal', false);
  }

  @action
  closed() {
    this.bufferedModel.discardChanges();
    this.set('openModal', false);
  }
}
