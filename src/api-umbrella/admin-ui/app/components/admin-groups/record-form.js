import classic from 'ember-classic-decorator';
import { action } from '@ember/object';
import { tagName } from '@ember-decorators/component';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
// eslint-disable-next-line ember/no-mixins
import Save from 'api-umbrella-admin-ui/mixins/save';
import escape from 'lodash-es/escape';

// eslint-disable-next-line ember/no-classic-classes
@classic
@tagName("")
export default class RecordForm extends Component.extend(Save) {
  @action
  submitForm() {
    this.saveRecord({
      transitionToRoute: 'admin_groups',
      message: 'Successfully saved the admin group "' + escape(this.model.name) + '"',
    });
  }

  @action
  delete() {
    this.destroyRecord({
      prompt: 'Are you sure you want to delete the admin group "' + escape(this.model.name) + '"?',
      transitionToRoute: 'admin_groups',
      message: 'Successfully deleted the admin group "' + escape(this.model.name) + '"',
    });
  }
}
