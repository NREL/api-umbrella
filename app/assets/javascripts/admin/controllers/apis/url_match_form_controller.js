Admin.ApisUrlMatchFormController = Admin.NestedFormController.extend({
  titleBase: 'Matching URL Prefix',
  exampleSuffix: 'example.json?param=value',

  exampleIncomingUrl: function() {
    var root = this.get('apiModel.exampleIncomingUrlRoot') || '';
    var prefix = this.get('frontendPrefix') || '';
    return root + prefix + this.get('exampleSuffix');
  }.property('frontendPrefix'),

  exampleOutgoingUrl: function() {
    var root = this.get('apiModel.exampleOutgoingUrlRoot') || '';
    var prefix = this.get('backendPrefixWithDefault') || '';
    return root + prefix + this.get('exampleSuffix');
  }.property('backendPrefix', 'frontendPrefix'),
});
