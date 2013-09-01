Admin.ApisUrlMatchFormController = Admin.NestedFormController.extend({
  titleBase: 'Matching URL Prefix',
  exampleSuffix: 'example.json?param=value',

  exampleIncomingUrl: function() {
    return this.get('apiModel').get('exampleIncomingUrlRoot') + this.get('frontendPrefix') + this.get('exampleSuffix');
  }.property('frontendPrefix'),

  exampleOutgoingUrl: function() {
    return this.get('apiModel').get('exampleOutgoingUrlRoot') + this.get('backendPrefixWithDefault') + this.get('exampleSuffix');
  }.property('backendPrefix', 'frontendPrefix'),
});
