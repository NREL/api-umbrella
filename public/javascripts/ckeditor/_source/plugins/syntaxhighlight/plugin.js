CKEDITOR.plugins.add('syntaxhighlight',
{
	requires : [ 'dialog' ],
	lang : [ 'en' ],
	
	init : function(editor)
	{
		var pluginName = 'syntaxhighlight';
		var command = editor.addCommand(pluginName, new CKEDITOR.dialogCommand(pluginName) );
		command.modes = { wysiwyg:1, source:1 };
		command.canUndo = false;

		editor.ui.addButton('Code',
		{
				label : editor.lang.syntaxhighlight.title,
				command : pluginName,
				icon: this.path + 'images/syntaxhighlight.gif'
		});

		CKEDITOR.dialog.add(pluginName, this.path + 'dialogs/syntaxhighlight.js' );
	}
});

