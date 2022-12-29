// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { reads } from '@ember/object/computed';
import { inject } from '@ember/service';
import { tagName } from '@ember-decorators/component';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import bootbox from 'bootbox';
import classic from 'ember-classic-decorator';
import escape from 'lodash-es/escape';
import without from 'lodash-es/without';

@classic
@tagName("")
export default class RecordForm extends Component.extend(Save) {
  @inject()
  session;

  @reads('session.data.authenticated.admin')
  currentAdmin;

  backendProtocolOptions = [
    { id: 'http', name: 'http' },
    { id: 'https', name: 'https' },
  ];

  balanceAlgorithmOptions = [
    { id: 'least_conn', name: 'Least Connections' },
    { id: 'round_robin', name: 'Round Robin' },
    { id: 'ip_hash', name: 'Source IP Hash' },
  ];

  @action
  submitForm(event) {
    event.preventDefault();
    this.saveRecord({
      element: event.target,
      transitionToRoute: 'apis',
      message: 'Successfully saved the "' + escape(this.model.name) + '" API backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
    });
  }

  @action
  delete() {
    this.destroyRecord({
      prompt: 'Are you sure you want to delete the API backend "' + escape(this.model.name) + '"?',
      transitionToRoute: 'apis',
      message: 'Successfully deleted the "' + escape(this.model.name) + '" API backend<br><strong>Note:</strong> Your changes are not yet live. <a href="/admin/#/config/publish">Publish Changes</a> to send your updates live.',
    });
  }

  @action
  addUrlMatch() {
    this.controllers.apis_url_match_form.add(this.model, 'urlMatches');
  }

  @action
  editUrlMatch(urlMatch) {
    this.controllers.apis_url_match_form.edit(this.model, 'urlMatches', urlMatch);
  }

  @action
  deleteUrlMatch(urlMatch) {
    this.deleteChildRecord('urlMatches', urlMatch, 'Are you sure you want to remove this URL prefix?');
  }

  @action
  addSubSettings() {
    this.controllers.apis_sub_settings_form.add(this.model, 'subSettings');
  }

  @action
  editSubSettings(subSettings) {
    this.controllers.apis_sub_settings_form.edit(this.model, 'subSettings', subSettings);
  }

  @action
  deleteSubSettings(subSettings) {
    this.deleteChildRecord('subSettings', subSettings, 'Are you sure you want to remove this URL setting?');
  }

  @action
  addRewrite() {
    this.controllers.apis_rewrite_form.add(this.model, 'rewrites');
  }

  @action
  editRewrite(rewrite) {
    this.controllers.apis_rewrite_form.edit(this.model, 'rewrites', rewrite);
  }

  @action
  deleteRewrite(rewrite) {
    this.deleteChildRecord('rewrites', rewrite, 'Are you sure you want to remove this rewrite?');
  }

  deleteChildRecord(collectionName, record, message) {
    bootbox.confirm(message, (result) => {
      if(result) {
        let collection = without(this.model.get(collectionName), record);
        this.model.set(collectionName, collection)
      }
    });
  }
}
