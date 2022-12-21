// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { guidFor } from '@ember/object/internals';
import { tracked } from '@glimmer/tracking';
import classic from 'ember-classic-decorator';

@classic
class BaseField extends Component {
  static positionalParams = ['fieldName'];

  tagName = '';

  @tracked fieldName;

  init() {
    super.init(...arguments);
  }

  get inputId() {
    return guidFor(this) + '-' + this.fieldName;
  }
}

export default BaseField;
