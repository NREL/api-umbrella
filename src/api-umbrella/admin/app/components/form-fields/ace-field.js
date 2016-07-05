import BaseField from './base-field';

export default BaseField.extend({
  init: function() {
    this._super();
    this.set('aceId', this.get('elementId') + '_ace');
    this.set('aceTextInputId', this.get('elementId') + '_ace_text_input');
    this.set('overrideForElementId', this.get('aceTextInputId'));
  },

  didInsertElement: function() {
    this._super();

    var aceId = this.get('aceId');
    var $element = this.$().find('textarea');
    $element.hide();
    $element.before('<div id="' + aceId + '" data-form-property="' + this.property + '" class="span12"></div>');

    this.editor = ace.edit(aceId);

    var editor = this.editor;
    var session = this.editor.getSession();

    editor.setTheme('ace/theme/textmate');
    editor.setShowPrintMargin(false);
    editor.setHighlightActiveLine(false);
    session.setUseWorker(false);
    session.setTabSize(2);
    session.setMode('ace/mode/' + $element.data('ace-mode'));
    session.setValue($element.val());

    var $textElement = $(editor.textInput.getElement());
    $textElement.attr('id', this.get('aceTextInputId'));
    $textElement.attr('data-raw-input-id', this.get('elementId'));

    var contentId = this.get('elementId') + '_ace_content';
    var $content = $(editor.container).find('.ace_content');
    $content.attr('id', contentId);
    $textElement.attr('data-ace-content-id', contentId);

    session.on('change', function() {
      $element.val(session.getValue());
      $element.trigger('change');
    });
  },
});
