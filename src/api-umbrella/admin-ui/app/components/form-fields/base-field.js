import classic from 'ember-classic-decorator';
import { computed } from '@ember/object';
// eslint-disable-next-line ember/no-classic-components
import Component from '@ember/component';

// eslint-disable-next-line ember/no-classic-classes
@classic
class BaseField extends Component {
  @computed('elementId', 'fieldName')
  get inputId() {
    return this.elementId + '-' + this.fieldName;
  }
}

BaseField.reopenClass({
  positionalParams: ['fieldName'],
});

export default BaseField;
