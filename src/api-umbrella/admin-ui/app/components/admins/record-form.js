import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { tagName } from '@ember-decorators/component';
import { inject } from '@ember/service';
import { reads } from '@ember/object/computed';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import escape from 'lodash-es/escape';

// eslint-disable-next-line ember/no-classic-classes
@classic
@tagName("")
export default class RecordForm extends Component.extend(Save) {
  @inject()
  session;

  @reads('session.data.authenticated.admin')
  currentAdmin;

  @action
  submitForm() {
    this.saveRecord({
      transitionToRoute: 'admins',
      message: 'Successfully saved the admin "' + escape(this.model.username) + '"',
    });
  }

  @action
  delete() {
    this.destroyRecord({
      prompt: 'Are you sure you want to delete the admin "' + escape(this.model.username) + '"?',
      transitionToRoute: 'admins',
      message: 'Successfully deleted the admin "' + escape(this.model.username) + '"',
    });
  }
}
