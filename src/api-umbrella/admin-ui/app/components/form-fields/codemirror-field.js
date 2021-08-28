import 'codemirror/addon/display/autorefresh';
import 'codemirror/mode/javascript/javascript';
import 'codemirror/mode/xml/xml';
import 'codemirror/mode/yaml/yaml';

import { action } from '@ember/object';
import CodeMirror from 'codemirror/lib/codemirror'
import classic from 'ember-classic-decorator';
import $ from 'jquery';

import BaseField from './base-field';

@classic
export default class CodemirrorField extends BaseField {
  init() {
    super.init();
    this.set('codemirrorInputFieldId', this.inputId + '_codemirror_input_field');
    this.set('codemirrorWrapperElementId', this.inputId + '_codemirror_wrapper_element');
    // eslint-disable-next-line ember/no-observers
    this.addObserver('model.' + this.fieldName, this, this.valueDidChange);
  }

  @action
  didInsert(element) {
    const originalTextarea = element.querySelector('textarea');
    const $originalTextarea = $(originalTextarea);

    this.codemirror = CodeMirror.fromTextArea(originalTextarea, {
      lineNumbers: true,
      mode: originalTextarea.dataset.codemirrorMode,
      tabSize: 2,

      // Enable auto-refresh plugin to fix codemirror creation fields that may
      // be hidden originally (eg, hidden under collapsed form sections).
      autoRefresh: true,
    });

    // Set the id on the codemirror input to match the field's label so that
    // when clicking on the label the codemirror input gains focus.
    const inputField = this.codemirror.getInputField();
    if(inputField) {
      inputField.id = this.codemirrorInputFieldId;

      const wrapperElement = this.codemirror.getWrapperElement();
      if(wrapperElement) {
        wrapperElement.id = this.codemirrorWrapperElementId;
      }

      inputField.setAttribute('data-codemirror-wrapper-element-id', this.codemirrorWrapperElementId);
      inputField.setAttribute('data-codemirror-original-textarea-id', originalTextarea.getAttribute('id'));
    }

    // Sync the codemirror changes back to the original textarea which will
    // will update the model.
    this.codemirror.on('change', () => {
      this.codemirror.save();
      $originalTextarea.trigger('input');
    });
  }

  valueDidChange() {
    // Sync any external model changes back to the code mirror input.
    if(this.codemirror) {
      const currentValue = this.codemirror.getValue()
      const newValue = this.get('model.' + this.fieldName);
      if(currentValue !== newValue) {
        this.codemirror.setValue(newValue);
      }
    }
  }
}
