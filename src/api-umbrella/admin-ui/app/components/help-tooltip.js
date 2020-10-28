import Component from '@ember/component';
import { computed } from '@ember/object';
import marked from 'marked';

export default Component.extend({
  tagName: 'span',

  tooltipHtml: computed('tooltip', function() {
    return marked(this.tooltip);
  }),
});
