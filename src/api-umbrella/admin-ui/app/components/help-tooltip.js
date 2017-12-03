import Ember from 'ember';

export default Ember.Component.extend({
  tagName: 'span',

  tooltipHtml: Ember.computed('tooltip', function() {
    return marked(this.get('tooltip'));
  }),
});
