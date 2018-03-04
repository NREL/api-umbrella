import $ from 'jquery';
import Mixin from '@ember/object/mixin'
import { computed } from '@ember/object';
import { guidFor } from '@ember/object/internals';

export default Mixin.create({
  isReorderable: computed('sortableCollection.length', function() {
    let length = this.get('sortableCollection.length');
    return (length && length > 1);
  }),

  updateSortOrder(indexes) {
    this.get('sortableCollection').forEach(function(record) {
      let index = indexes[guidFor(record)];
      record.set('sortOrder', index);
    });
  },

  actions: {
    reorderCollection(containerId) {
      let $container = $('#' + containerId);
      let $buttonText = $container.find('.reorder-button-text');

      if($container.hasClass('reorder-active')) {
        $buttonText.text($buttonText.data('originalText'));
      } else {
        $buttonText.data('originalText',  $buttonText.text());
        $buttonText.text('Done');
      }

      $container.toggleClass('reorder-active');

      let self = this;
      $container.find('tbody').sortable({
        handle: '.reorder-handle',
        placeholder: 'reorder-placeholder',
        helper(event, ui) {
          ui.children().each(function() {
            $(this).width($(this).width());
          });
          return ui;
        },
        stop() {
          let indexes = {};
          $(this).find('tr').each(function(index) {
            indexes[$(this).data('guid')] = index;
          });

          self.updateSortOrder(indexes);
        },
      });
    },
  },
});
