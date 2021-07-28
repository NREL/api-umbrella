// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';
import { computed } from '@ember/object';
import classic from 'ember-classic-decorator';

@classic
class BaseField extends Component {
  tagName = '';

  @computed('elementId', 'fieldName')
  get inputId() {
    return this.elementId + '-' + this.fieldName;
  }
}

BaseField.reopenClass({
  positionalParams: ['fieldName'],
});

export default BaseField;
