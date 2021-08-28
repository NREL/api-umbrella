import 'selectize';

import { action } from '@ember/object';
import { observes, on } from '@ember-decorators/object';
import classic from 'ember-classic-decorator';
import $ from 'jquery';
import uniq from 'lodash-es/uniq';

import BaseField from './base-field';

@classic
export default class SelectizeField extends BaseField {
  optionValuePath = 'id';
  optionLabelPath = 'id';

  init() {
    super.init(...arguments);

    this.defaultOptions =  [];

    this.set('selectizeTextInputId', this.inputId + '-selectize_text_input');
    // eslint-disable-next-line ember/no-observers
    this.addObserver('model.' + this.fieldName, this, this.valueDidChange);
  }

  @action
  didInsert(element) {
    this.$input = $(element).find('#' + this.inputId).selectize({
      plugins: ['restore_on_backspace', 'remove_button'],
      delimiter: ',',
      options: this.defaultOptions,
      valueField: 'id',
      labelField: 'label',
      searchField: 'label',
      sortField: 'label',
      create: true,

      // Add to body so it doesn't get clipped by parent div containers.
      dropdownParent: 'body',
    });

    this.selectize = this.$input[0].selectize;
    this.selectize.$control_input.attr('id', this.selectizeTextInputId);
    this.selectize.$control_input.attr('data-raw-input-id', this.inputId);

    let controlId = this.inputId + '-selectize_control';
    this.selectize.$control.attr('id', controlId);
    this.selectize.$control_input.attr('data-selectize-control-id', controlId);
  }

  @on('init')
  // eslint-disable-next-line ember/no-observers
  @observes('options.@each')
  defaultOptionsDidChange() {
    this.set('defaultOptions', this.options.map((item) => {
      return {
        id: item.get(this.optionValuePath),
        label: item.get(this.optionLabelPath),
      };
    }));

    if(this.selectize) {
      this.defaultOptions.forEach((option) => {
        this.selectize.addOption(option);
      });

      this.selectize.refreshOptions(false);
    }
  }

  // Sync the selectize input with the value binding if the value changes
  // externally.
  valueDidChange() {
    if(this.selectize) {
      let valueString = this.get('model.' + this.fieldName)
      if(valueString !== this.selectize.getValue()) {
        let values = valueString;
        if(values) {
          values = uniq(values.split(','));

          // Ensure the selected value is available as an option in the menu.
          // This takes into account the fact that the default options may not
          // be loaded yet, or they may not contain this specific option.
          for(let i = 0; i < values.length; i++) {
            let option = {
              id: values[i],
              label: values[i],
            };

            this.selectize.addOption(option);
          }

          this.selectize.refreshOptions(false);
        }

        this.selectize.setValue(values);
      }
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    if(this.selectize) {
      this.selectize.destroy();
    }
  }
}
