// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { action } from '@ember/object';
import { reads } from '@ember/object/computed';
import { inject } from '@ember/service';
import { tagName } from '@ember-decorators/component';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import classic from 'ember-classic-decorator';
import escape from 'lodash-es/escape';

@classic
@tagName("")
export default class RecordForm extends Component.extend(Save) {
  @inject()
  session;

  @reads('session.data.authenticated.admin')
  currentAdmin;

  @action
  submitForm(event) {
    event.preventDefault();
    this.saveRecord({
      element: event.target,
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
