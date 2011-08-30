CKEDITOR.dialog.add('syntaxhighlight', function(editor)
{    
    var parseHtml = function(htmlString) {
        htmlString = htmlString.replace(/<br>/g, '\n');
        htmlString = htmlString.replace(/&amp;/g, '&');
        htmlString = htmlString.replace(/&lt;/g, '<');
        htmlString = htmlString.replace(/&gt;/g, '>');
        htmlString = htmlString.replace(/&quot;/g, '"');
        return htmlString;
    }
    
    var getDefaultOptions = function(options) {
        var options = new Object();
        options.hideGutter = false;
        options.hideControls = false;
        options.collapse = false;
        options.showColumns = false;
        options.noWrap = false;
        options.firstLineChecked = false;
        options.firstLine = 0;
        options.highlightChecked = false;
        options.highlight = null;
        options.lang = null;
        options.code = '';
        return options;
    }
    
    var getOptionsForString = function(optionsString) {
        var options = getDefaultOptions();
        if (optionsString) {
            if (optionsString.indexOf("brush") > -1) {
                var match = /brush:[ ]{0,1}(\w*)/.exec(optionsString);
                if (match != null && match.length > 0) {
                    options.lang = match[1].replace(/^\s+|\s+$/g, "");
                }
            }
            
            if (optionsString.indexOf("gutter") > -1)
                options.hideGutter = true;

            if (optionsString.indexOf("toolbar") > -1)
                options.hideControls = true;

            if (optionsString.indexOf("collapse") > -1)
                options.collapse = true;

            if (optionsString.indexOf("first-line") > -1) {
                var match = /first-line:[ ]{0,1}([0-9]{1,4})/.exec(optionsString);
                if (match != null && match.length > 0 && match[1] > 1) {
                    options.firstLineChecked = true;
                    options.firstLine = match[1];
                }
            }
            
            if (optionsString.indexOf("highlight") > -1) {
                // make sure we have a comma-seperated list
                if (optionsString.match(/highlight:[ ]{0,1}\[[0-9]+(,[0-9]+)*\]/)) {
                    // now grab the list
                    var match_hl = /highlight:[ ]{0,1}\[(.*)\]/.exec(optionsString);
                    if (match_hl != null && match_hl.length > 0) {
                        options.highlightChecked = true;
                        options.highlight = match_hl[1];
                    }
                }
            }

            if (optionsString.indexOf("ruler") > -1)
                options.showColumns = true;
            
            if (optionsString.indexOf("wrap-lines") > -1)
                options.noWrap = true;
        }
        return options;
    }
    
    var getStringForOptions = function(optionsObject) {
        var result = 'brush:' + optionsObject.lang + ';';
        if (optionsObject.hideGutter)
            result += 'gutter:false;';
        if (optionsObject.hideControls)
            result += 'toolbar:false;';
        if (optionsObject.collapse)
            result += 'collapse:true;';
        if (optionsObject.showColumns)
            result += 'ruler:true;';
        if (optionsObject.noWrap)
            result += 'wrap-lines:false;';
        if (optionsObject.firstLineChecked && optionsObject.firstLine > 1)
            result += 'first-line:' + optionsObject.firstLine + ';';
        if (optionsObject.highlightChecked && optionsObject.highlight != '')
            result += 'highlight: [' + optionsObject.highlight.replace(/\s/gi, '') + '];';
        return result;
    }
    
    return {
        title: editor.lang.syntaxhighlight.title,
        minWidth: 500,
        minHeight: 400,
        onShow: function() {
            // Try to grab the selected pre tag if any
            var editor = this.getParentEditor();
            var selection = editor.getSelection();
            var element = selection.getStartElement();
            var preElement = element && element.getAscendant('pre', true);
            
            // Set the content for the textarea
            var text = '';
            var optionsObj = null;
            if (preElement) {
                code = parseHtml(preElement.getHtml());
                optionsObj = getOptionsForString(preElement.getAttribute('class'));
                optionsObj.code = code;
            } else {
                optionsObj = getDefaultOptions();
            }
            this.setupContent(optionsObj);
        },
        onOk: function() {
            var editor = this.getParentEditor();
            var selection = editor.getSelection();
            var element = selection.getStartElement();
            var preElement = element && element.getAscendant('pre', true);
            var data = getDefaultOptions();
            this.commitContent(data);
            var optionsString = getStringForOptions(data);
            
            if (preElement) {
                preElement.setAttribute('class', optionsString);
                preElement.setText(data.code);
            } else {
                var newElement = new CKEDITOR.dom.element('pre');
                newElement.setAttribute('class', optionsString);
                newElement.setText(data.code);
                editor.insertElement(newElement);
            }
        },
        contents : [
            {
                id : 'source',
                label : editor.lang.syntaxhighlight.sourceTab,
                accessKey : 'S',
                elements :
                [
                    {
                        type : 'vbox',
                        children: [
                          {
                              id: 'cmbLang',
                              type: 'select',
                              labelLayout: 'horizontal',
                              label: editor.lang.syntaxhighlight.langLbl,
                              'default': 'java',
                              widths : [ '25%','75%' ],
                              items: [
                                      ['Bash (Shell)', 'bash'],
                                      ['C#', 'csharp'],
                                      ['C++', 'cpp'],
                                      ['CSS', 'css'],
                                      ['Delphi', 'delphi'],
                                      ['Diff', 'diff'],
                                      ['Groovy', 'groovy'],
                                      ['Javascript', 'jscript'],
                                      ['Java', 'java'],
                                      ['Java FX', 'javafx'],
                                      ['Perl', 'perl'],
                                      ['PHP', 'php'],
                                      ['Plain (Text)', 'plain'],
                                      ['Python', 'python'],
                                      ['Ruby', 'ruby'],
                                      ['Scala', 'scala'],
                                      ['SQL', 'sql'],
                                      ['VB', 'vb'],
                                      ['XML/XHTML', 'xml']
                              ],
                              setup: function(data) {
                                  if (data.lang)
                                      this.setValue(data.lang);
                              },
                              commit: function(data) {
                                  data.lang = this.getValue();
                              }
                          }
                        ]
                    },
                    {
                        type: 'textarea',
                        id: 'hl_code',
                        rows: 22,
                        style: "width: 100%",
                        setup: function(data) {
                            if (data.code)
                                this.setValue(data.code);
                        },
                        commit: function(data) {
                            data.code = this.getValue();
                        }
                    }
                ]
            },
            {
                id : 'advanced',
                label : editor.lang.syntaxhighlight.advancedTab,
                accessKey : 'A',
                elements :
                [
                    {
                        type : 'vbox',
                        children: [
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.hideGutter + '</strong>'
                          },
                          {
                              type: 'checkbox',
                              id: 'hide_gutter',
                              label: editor.lang.syntaxhighlight.hideGutterLbl,
                              setup: function(data) {
                                  this.setValue(data.hideGutter)
                              },
                              commit: function(data) {
                                  data.hideGutter = this.getValue();
                              }
                          },
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.hideControls + '</strong>'
                          },
                          {
                              type: 'checkbox',
                              id: 'hide_controls',
                              label: editor.lang.syntaxhighlight.hideControlsLbl,
                              setup: function(data) {
                                  this.setValue(data.hideControls)
                              },
                              commit: function(data) {
                                  data.hideControls = this.getValue();
                              }
                          },
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.collapse + '</strong>'
                          },
                          {
                              type: 'checkbox',
                              id: 'collapse',
                              label: editor.lang.syntaxhighlight.collapseLbl,
                              setup: function(data) {
                                  this.setValue(data.collapse)
                              },
                              commit: function(data) {
                                  data.collapse = this.getValue();
                              }
                          },
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.showColumns + '</strong>'
                          },
                          {
                              type: 'checkbox',
                              id: 'show_columns',
                              label: editor.lang.syntaxhighlight.showColumnsLbl,
                              setup: function(data) {
                                  this.setValue(data.showColumns)
                              },
                              commit: function(data) {
                                  data.showColumns = this.getValue();
                              }
                          },
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.lineWrap + '</strong>'
                          },
                          {
                              type: 'checkbox',
                              id: 'line_wrap',
                              label: editor.lang.syntaxhighlight.lineWrapLbl,
                              setup: function(data) {
                                  this.setValue(data.noWrap);
                              },
                              commit: function(data) {
                                  data.noWrap = this.getValue();
                              }
                          },
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.lineCount + '</strong>'
                          },
                          {
                              type: 'hbox',
                              widths: [ '5%', '95%' ],
                              children: [
                                 {
                                     type: 'checkbox',
                                     id: 'lc_toggle',
                                     label: '',
                                     setup: function(data) {
                                          this.setValue(data.firstLineChecked);
                                     },
                                     commit: function(data) {
                                         data.firstLineChecked = this.getValue();
                                     }
                                 },
                                 {
                                     type: 'text',
                                     id: 'default_lc',
                                     style: 'width: 15%;',
                                     label: '',
                                     setup: function(data) {
                                         if (data.firstLine > 1)
                                             this.setValue(data.firstLine);
                                     },
                                     commit: function(data) {
                                         if (this.getValue() && this.getValue() != '')
                                             data.firstLine = this.getValue();
                                     }
                                 }
                              ]
                          },
                          {
                              type: 'html',
                              html: '<strong>' + editor.lang.syntaxhighlight.highlight + '</strong>'
                          },
                          {
                              type: 'hbox',
                              widths: [ '5%', '95%' ],
                              children: [
                                 {
                                     type: 'checkbox',
                                     id: 'hl_toggle',
                                     label: '',
                                     setup: function(data) {
                                         this.setValue(data.highlightChecked)
                                     },
                                     commit: function(data) {
                                         data.highlightChecked = this.getValue();
                                     }
                                 },
                                 {
                                     type: 'text',
                                     id: 'default_hl',
                                     style: 'width: 40%;',
                                     label: '',
                                     setup: function(data) {
                                         if (data.highlight != null)
                                             this.setValue(data.highlight);
                                     },
                                     commit: function(data) {
                                         if (this.getValue() && this.getValue() != '')
                                             data.highlight = this.getValue();
                                     }
                                 }
                              ]
                          },
                          {
                              type: 'hbox',
                              widths: [ '5%', '95%' ],
                              children: [
                                  {type: 'html', html: ''},
                                  {
                                      type: 'html',
                                      html: '<i>' + editor.lang.syntaxhighlight.highlightLbl + '</i>'
                                  }
                              ]
                          }
                        ]
                    }
                ]
            }
        ]
    };
});
