import { action } from '@ember/object';
import { classNames } from '@ember-decorators/component';

import BaseField from './base-field';

@classNames('form-fields-checkboxes-field')
export default class CheckboxesField extends BaseField {
  get checkboxes() {
    const checkedValues = this.model[this.fieldName];

    return this.options.map((option) => {
      return {
        option: option,
        isChecked: checkedValues.includes(option.id),
        inputId: `${this.inputId}-${option.id}`,
      }
    });
  }

  @action
  toggleCheckbox(value, checked) {
    const checkedValues = this.model.get(this.fieldName);

    if(checked === true && !checkedValues.includes(value)) {
      checkedValues.addObject(value);
    } else if(checked === false && checkedValues.includes(value)) {
      checkedValues.removeObject(value);
    }
  }
}
