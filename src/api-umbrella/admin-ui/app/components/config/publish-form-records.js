import $ from 'jquery';
import Component from '@ember/component';

export default Component.extend({
  actions: {
    toggleConfigDiff(id) {
      $('[data-diff-id=' + id + ']').toggle();
    },
  },
});
