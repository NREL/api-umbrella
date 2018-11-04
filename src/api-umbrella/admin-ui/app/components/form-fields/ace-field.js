import 'ace-builds/src-noconflict/mode-json';
import 'ace-builds/src-noconflict/mode-xml';
import 'ace-builds/src-noconflict/mode-yaml';
import $ from 'jquery';
import BaseField from './base-field';
import ace from 'ace-builds/src-noconflict/ace'

export default BaseField.extend({
  init() {
    this._super();
    this.set('aceId', this.elementId + '_ace');
    this.set('aceTextInputId', this.elementId + '_ace_text_input');
    this.addObserver('model.' + this.fieldName, this, this.valueDidChange);
  },

  didInsertElement() {
    this._super();

    let aceId = this.aceId;
    let $element = this.$().find('textarea');
    $element.hide();
    $element.before('<div id="' + aceId + '" data-form-property="' + this.fieldName + '" class="span12"></div>');

    this.editor = ace.edit(aceId);

    let editor = this.editor;
    let session = this.editor.getSession();

    editor.$blockScrolling = Infinity;
    editor.setTheme('ace/theme/textmate');
    editor.setShowPrintMargin(false);
    editor.setHighlightActiveLine(false);
    session.setUseWorker(false);
    session.setTabSize(2);
    session.setMode('ace/mode/' + $element.data('ace-mode'));
    session.setValue($element.val());

    let $textElement = $(editor.textInput.getElement());
    $textElement.attr('id', this.aceTextInputId);
    $textElement.attr('data-raw-input-id', $element.attr('id'));

    let contentId = this.elementId + '_ace_content';
    let $content = $(editor.container).find('.ace_content');
    $content.attr('id', contentId);
    $textElement.attr('data-ace-content-id', contentId);

    session.on('change', function() {
      $element.val(session.getValue());
      $element.trigger('change');
    });
  },

  valueDidChange() {
    if(this.editor) {
      let session = this.editor.getSession();
      let value = this.get('model.' + this.fieldName);
      if(value !== session.getValue()) {
        session.setValue(value);
      }
    }
  },
});
