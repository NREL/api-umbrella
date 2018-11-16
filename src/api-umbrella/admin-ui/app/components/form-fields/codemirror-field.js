import 'codemirror/addon/display/autorefresh';
import 'codemirror/mode/javascript/javascript';
import 'codemirror/mode/xml/xml';
import 'codemirror/mode/yaml/yaml';
import BaseField from './base-field';
import CodeMirror from 'codemirror/lib/codemirror'

export default BaseField.extend({
  init() {
    this._super();
    this.set('codemirrorInputFieldId', this.elementId + '_codemirror_input_field');
    this.set('codemirrorWrapperElementId', this.elementId + '_codemirror_wrapper_element');
    this.addObserver('model.' + this.fieldName, this, this.valueDidChange);
  },

  didInsertElement() {
    this._super();

    let $originalTextarea = this.$().find('textarea');
    this.codemirror = CodeMirror.fromTextArea($originalTextarea[0], {
      lineNumbers: true,
      mode: $originalTextarea.data('codemirror-mode'),
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
      inputField.setAttribute('data-codemirror-original-textarea-id', $originalTextarea.attr('id'));
    }

    // Sync the codemirror changes back to the original textarea which will
    // will update the model.
    this.codemirror.on('change', () => {
      this.codemirror.save();
      $originalTextarea.trigger('change');
    });
  },

  valueDidChange() {
    // Sync any external model changes back to the code mirror input.
    if(this.codemirror) {
      const currentValue = this.codemirror.getValue()
      const newValue = this.get('model.' + this.fieldName);
      if(currentValue !== newValue) {
        this.codemirror.setValue(newValue);
      }
    }
  },
});
