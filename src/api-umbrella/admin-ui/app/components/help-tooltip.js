import Component from '@ember/component';
import { computed } from '@ember/object';

export default Component.extend({
  tagName: 'span',

  tooltipHtml: computed('tooltip', function() {
    return marked(this.get('tooltip'));
  }),
});
