import { classNames } from '@ember-decorators/component';
import classic from 'ember-classic-decorator';

import BaseField from './base-field';

@classNames('form-fields-checkboxes-field')
@classic
export default class CheckboxesField extends BaseField {
  get checkboxes() {
    const selectedValues = this.model[this.fieldName];
    console.info('selectedValues: ', selectedValues);
    console.info('options: ', this.options);

    return this.options.map((option) => {
      return {
        option: option,
        isSelected: selectedValues.includes(option.id),
      }
    });
  }
}
