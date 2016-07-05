import NestedForm from './nested-form';

export default NestedForm.extend({
  titleBase: 'Matching URL Prefix',
  exampleSuffix: 'example.json?param=value',

  exampleIncomingUrl: function() {
    let root = this.get('apiModel.exampleIncomingUrlRoot') || '';
    let prefix = this.get('frontendPrefix') || '';
    return root + prefix + this.get('exampleSuffix');
  }.property('frontendPrefix'),

  exampleOutgoingUrl: function() {
    let root = this.get('apiModel.exampleOutgoingUrlRoot') || '';
    let prefix = this.get('backendPrefixWithDefault') || '';
    return root + prefix + this.get('exampleSuffix');
  }.property('backendPrefix', 'frontendPrefix'),
});
