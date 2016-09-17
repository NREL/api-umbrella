import BaseField from './base-field';
import Ember from 'ember';

export default BaseField.extend({
  optionValuePath: 'id',
  optionLabelPath: 'id',
  defaultOptions: [],

  init() {
    this._super();
    this.set('selectizeTextInputId', this.get('elementId') + '-selectize_text_input');
  },

  didInsertElement() {
    this._super();

    this.$input = this.$().find('#' + this.get('inputId')).selectize({
      plugins: ['restore_on_backspace', 'remove_button'],
      delimiter: ',',
      options: this.get('defaultOptions'),
      valueField: 'id',
      labelField: 'label',
      searchField: 'label',
      sortField: 'label',
      onChange: _.bind(this.handleSelectizeChange, this),
      create: true,

      // Add to body so it doesn't get clipped by parent div containers.
      dropdownParent: 'body',
    });

    this.selectize = this.$input[0].selectize;
    this.selectize.$control_input.attr('id', this.get('selectizeTextInputId'));
    this.selectize.$control_input.attr('data-raw-input-id', this.get('inputId'));

    let controlId = this.get('elementId') + '-selectize_control';
    this.selectize.$control.attr('id', controlId);
    this.selectize.$control_input.attr('data-selectize-control-id', controlId);
  },

  defaultOptionsDidChange: Ember.on('init', Ember.observer('options.@each', function() {
    this.set('defaultOptions', this.get('options').map(_.bind(function(item) {
      return {
        id: item.get(this.get('optionValuePath')),
        label: item.get(this.get('optionLabelPath')),
      };
    }, this)));

    if(this.selectize) {
      this.get('defaultOptions').forEach(_.bind(function(option) {
        this.selectize.addOption(option);
      }, this));

      this.selectize.refreshOptions(false);
    }
  })),

  // Sync the selectize input with the value binding if the value changes
  // externally.
  valueDidChange: Ember.on('init', Ember.observer('value', function() {
    if(this.selectize) {
      let valueString = this.get('value');
      if(valueString !== this.selectize.getValue()) {
        let values = valueString;
        if(values) {
          values = _.uniq(values.split(','));

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
  })),

  // Update the value binding when the selectize input changes.
  handleSelectizeChange(value) {
    this.set('value', value);
  },

  willDestroyElement() {
    if(this.selectize) {
      this.selectize.destroy();
    }
  },
});
